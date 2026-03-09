//! Background swarm task runner + event channel.
//!
//! This module is intended to be used by a higher-level controller (e.g. `node::manager`)
//! to spawn a single libp2p `Swarm` running inside a Tokio task, and to receive a small
//! stream of status events that are easy to pass over FFI boundaries.
//!
//! TCP-first today; QUIC is a planned option (flag present in `NodeConfig`).

use anyhow::{anyhow, Context, Result};
use futures::StreamExt;
use libp2p::{
    identity,
    swarm::{Swarm, SwarmEvent},
    Multiaddr, PeerId,
};
use tokio::sync::{oneshot, watch};

use super::builder::{build_transport, NodeBehaviour, NodeBuildOptions, TransportConfig};

/// Configuration for spawning the swarm task.
///
/// Keep this "FFI-friendly": strings/booleans only.
#[derive(Debug, Clone)]
pub struct NodeConfig {
    /// Listen multiaddr, e.g. `/ip4/0.0.0.0/tcp/0`.
    pub listen_addr: Multiaddr,

    /// Reserved for future UI/debug.
    pub node_name: Option<String>,

    /// Future-proof: allows wiring QUIC later without changing public API.
    pub enable_quic: bool,
}

impl NodeConfig {
    pub fn tcp_default() -> Result<Self> {
        Ok(Self {
            listen_addr: "/ip4/0.0.0.0/tcp/0"
                .parse()
                .context("failed to parse default listen multiaddr")?,
            node_name: None,
            enable_quic: false,
        })
    }
}

/// Events emitted by the background task.
///
/// This is deliberately small/simple; later we can add richer events (connection list,
/// peer discovery, incoming messages, etc.) or add a separate event stream for chat.
#[derive(Debug, Clone)]
pub enum NodeEvent {
    Starting,
    Running { peer_id: String, listen_addrs: Vec<String> },
    Stopped { peer_id: String },
    Error { peer_id: Option<String>, message: String },
}

/// Returned by `spawn_swarm_task`.
pub struct SpawnedNode {
    pub peer_id: String,
    pub stop_tx: oneshot::Sender<()>,
    pub status_rx: watch::Receiver<NodeEvent>,
}

/// Spawn a background Tokio task that drives a libp2p swarm.
///
/// Returns a `stop_tx` to request shutdown and a `status_rx` to observe status updates.
///
/// Notes:
/// - This generates a fresh identity each time. For stable identities across restarts,
///   introduce a constructor that receives a stored private key.
/// - We currently keep status as a `watch` channel for "latest snapshot" semantics.
pub async fn spawn_swarm_task(config: NodeConfig) -> Result<SpawnedNode> {
    // Identity (future: load from storage)
    let id_keys = identity::Keypair::generate_ed25519();
    let peer_id = PeerId::from(id_keys.public()).to_string();

    // Build options: TCP for now, QUIC reserved.
    let mut opts = NodeBuildOptions::default();
    opts.transport = if config.enable_quic {
        // Not implemented yet, but keep the flag so API won't change later.
        TransportConfig::Quic
    } else {
        TransportConfig::Tcp
    };

    // Transport + behaviour
    let transport = build_transport(&id_keys, &opts).context("build_transport failed")?;

    let behaviour = NodeBehaviour::new(&id_keys.public(), &opts);

    // Swarm
    let mut swarm = Swarm::new(
        transport,
        behaviour,
        PeerId::from(id_keys.public()),
        libp2p::swarm::Config::with_tokio_executor(),
    );

    swarm
        .listen_on(config.listen_addr.clone())
        .map_err(|e| anyhow!("listen_on({config:?}) failed: {e}"))?;

    // Status channel
    let (status_tx, status_rx) = watch::channel(NodeEvent::Starting);

    // Stop signal
    let (stop_tx, stop_rx) = oneshot::channel::<()>();

    // Spawn loop
    tokio::spawn(async move {
        run_swarm_loop(swarm, stop_rx, status_tx).await;
    });

    Ok(SpawnedNode {
        peer_id,
        stop_tx,
        status_rx,
    })
}

async fn run_swarm_loop(
    mut swarm: Swarm<NodeBehaviour>,
    mut stop_rx: oneshot::Receiver<()>,
    status_tx: watch::Sender<NodeEvent>,
) {
    // Track latest state for `Running` updates.
    let peer_id = swarm.local_peer_id().to_string();
    let mut listen_addrs: Vec<String> = Vec::new();

    // Emit initial running snapshot once we get our first listen addr(s).
    // (We also send `Running` immediately with empty addrs.)
    let _ = status_tx.send(NodeEvent::Running {
        peer_id: peer_id.clone(),
        listen_addrs: listen_addrs.clone(),
    });

    loop {
        tokio::select! {
            _ = &mut stop_rx => {
                let _ = status_tx.send(NodeEvent::Stopped { peer_id });
                break;
            }
            event = swarm.select_next_some() => {
                if let Err(err) = handle_event(&mut listen_addrs, &status_tx, &peer_id, event) {
                    let _ = status_tx.send(NodeEvent::Error {
                        peer_id: Some(peer_id.clone()),
                        message: err.to_string(),
                    });
                    // Keep running despite errors; caller can decide to stop/restart.
                }
            }
        }
    }
}

fn handle_event(
    listen_addrs: &mut Vec<String>,
    status_tx: &watch::Sender<NodeEvent>,
    peer_id: &str,
    event: SwarmEvent<<NodeBehaviour as libp2p::swarm::NetworkBehaviour>::ToSwarm>,
) -> Result<()> {
    match event {
        SwarmEvent::NewListenAddr { address, .. } => {
            // Record and broadcast.
            listen_addrs.push(address.to_string());
            let _ = status_tx.send(NodeEvent::Running {
                peer_id: peer_id.to_string(),
                listen_addrs: listen_addrs.clone(),
            });
        }

        // These are useful for debugging now; later we can surface them to UI.
        SwarmEvent::IncomingConnection { send_back_addr, .. } => {
            eprintln!("[p2p] incoming connection from {send_back_addr}");
        }
        SwarmEvent::ConnectionEstablished { peer_id, endpoint, .. } => {
            eprintln!("[p2p] connection established: peer={peer_id} endpoint={endpoint:?}");
        }
        SwarmEvent::ConnectionClosed { peer_id, cause, .. } => {
            eprintln!("[p2p] connection closed: peer={peer_id} cause={cause:?}");
        }
        SwarmEvent::OutgoingConnectionError { peer_id, error, .. } => {
            eprintln!("[p2p] outgoing connection error: peer={peer_id:?} error={error}");
        }
        SwarmEvent::IncomingConnectionError { send_back_addr, error, .. } => {
            eprintln!("[p2p] incoming connection error: from={send_back_addr} error={error}");
        }

        // Ignore other events for now.
        _ => {}
    }

    Ok(())
}
