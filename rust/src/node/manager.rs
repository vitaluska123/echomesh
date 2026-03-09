//! Node manager: owns a single background libp2p swarm task for the whole process.
//!
//! Design goals:
//! - Keep a *single* node instance (singleton-like) so Dart can call start/stop safely.
//! - Don't leak libp2p types across the FRB boundary: API returns plain Strings/Results.
//! - Make it easy to extend transports later (e.g. QUIC) without rewriting public API.
//!
//! NOTE: This module intentionally does not expose FRB annotations; it is called from
//! `api.rs` functions that are annotated with `#[frb]`.

use anyhow::{anyhow, Context, Result};
use std::sync::{Mutex, OnceLock};
use tokio::sync::{oneshot, watch};

use crate::node::swarm_task::{spawn_swarm_task, NodeConfig, NodeEvent};

/// Global singleton storage.
static NODE_MANAGER: OnceLock<NodeManager> = OnceLock::new();

/// Get the global node manager.
pub fn global() -> &'static NodeManager {
    NODE_MANAGER.get_or_init(NodeManager::new)
}

/// Public state snapshot for UI/debugging.
#[derive(Debug, Clone)]
pub struct NodeStatus {
    pub running: bool,
    pub peer_id: Option<String>,
    pub listen_addrs: Vec<String>,
}

#[derive(Debug)]
struct NodeHandle {
    peer_id: String,
    stop_tx: oneshot::Sender<()>,
    status_rx: watch::Receiver<NodeEvent>,
}

/// Manages lifecycle of the libp2p swarm background task.
#[derive(Debug)]
pub struct NodeManager {
    inner: Mutex<Option<NodeHandle>>,
}

impl NodeManager {
    fn new() -> Self {
        Self {
            inner: Mutex::new(None),
        }
    }

    /// Start the node if it is not already running.
    ///
    /// Returns the node's `PeerId` string.
    pub async fn start(&self, config: NodeConfig) -> Result<String> {
        // Fast-path check under lock.
        {
            let guard = self
                .inner
                .lock()
                .map_err(|_| anyhow!("node manager mutex poisoned"))?;
            if let Some(handle) = guard.as_ref() {
                return Ok(handle.peer_id.clone());
            }
        }

        // Spawn outside the lock to avoid holding mutex across await.
        let spawned = spawn_swarm_task(config)
            .await
            .context("failed to spawn swarm task")?;

        // Install handle, but handle races (two concurrent start calls).
        let mut guard = self
            .inner
            .lock()
            .map_err(|_| anyhow!("node manager mutex poisoned"))?;
        if let Some(existing) = guard.as_ref() {
            // Another caller started it; stop the newly spawned one to avoid double-swarmed process.
            let _ = spawned.stop_tx.send(());
            return Ok(existing.peer_id.clone());
        }

        *guard = Some(NodeHandle {
            peer_id: spawned.peer_id.clone(),
            stop_tx: spawned.stop_tx,
            status_rx: spawned.status_rx,
        });

        Ok(spawned.peer_id)
    }

    /// Stop the node if running.
    pub fn stop(&self) -> Result<()> {
        let mut guard = self
            .inner
            .lock()
            .map_err(|_| anyhow!("node manager mutex poisoned"))?;

        let Some(handle) = guard.take() else {
            return Ok(());
        };

        // Signal stop. We don't await the join here; the task should exit soon.
        let _ = handle.stop_tx.send(());
        Ok(())
    }

    /// Get peer id if running.
    pub fn peer_id(&self) -> Result<Option<String>> {
        let guard = self
            .inner
            .lock()
            .map_err(|_| anyhow!("node manager mutex poisoned"))?;
        Ok(guard.as_ref().map(|h| h.peer_id.clone()))
    }

    /// Subscribe to node events (useful for UI).
    ///
    /// Each call returns an independent receiver clone.
    pub fn subscribe(&self) -> Result<Option<watch::Receiver<NodeEvent>>> {
        let guard = self
            .inner
            .lock()
            .map_err(|_| anyhow!("node manager mutex poisoned"))?;
        Ok(guard.as_ref().map(|h| h.status_rx.clone()))
    }

    /// Best-effort snapshot of current status.
    pub fn status(&self) -> Result<NodeStatus> {
        let guard = self
            .inner
            .lock()
            .map_err(|_| anyhow!("node manager mutex poisoned"))?;

        let Some(handle) = guard.as_ref() else {
            return Ok(NodeStatus {
                running: false,
                peer_id: None,
                listen_addrs: vec![],
            });
        };

        // We only have the last event; keep it simple for now.
        let event = handle.status_rx.borrow().clone();
        let (peer_id, listen_addrs) = match &event {
            NodeEvent::Starting => (Some(handle.peer_id.clone()), vec![]),
            NodeEvent::Running { peer_id, listen_addrs } => {
                (Some(peer_id.clone()), listen_addrs.clone())
            }
            NodeEvent::Stopped { peer_id } => (Some(peer_id.clone()), vec![]),
            NodeEvent::Error { peer_id, .. } => (peer_id.clone(), vec![]),
        };

        Ok(NodeStatus {
            running: !matches!(event, NodeEvent::Stopped { .. }),
            peer_id,
            listen_addrs,
        })
    }

    /// Ensure the node is stopped (useful for tests / app shutdown hooks).
    pub fn stop_if_running(&self) {
        let _ = self.stop();
    }
}
