//! Node builder.
//!
//! Goal: keep transport/security/mux configuration in one place so we can
//! switch TCP → QUIC (or add both) without rewriting the whole node.
//!
//! For now we build a TCP+Noise+Yamux transport suitable for:
//!   - Desktop (Linux/Windows/macOS)
//!   - Android (within the constraints of the platform)
//!
//! Later we can add QUIC and/or relay configuration behind the same API.

use anyhow::Result;
use libp2p::{
    core::{
        muxing::StreamMuxerBox,
        transport::{Boxed, OrTransport},
        upgrade,
    },
    dns, identify, identity,
    noise,
    ping,
    swarm::NetworkBehaviour,
    tcp, yamux, PeerId, Transport,
};

/// Which transports are enabled for the node.
///
/// Keep this extensible; QUIC can be added later without touching the
/// rest of the codebase.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransportConfig {
    /// TCP transport (with optional DNS).
    Tcp,
    /// Placeholder for future QUIC support.
    ///
    /// Not implemented yet; if selected, builder will return an error.
    Quic,
    /// Placeholder for enabling multiple transports side-by-side.
    ///
    /// Not implemented yet; can be used when we introduce `OrTransport`.
    TcpAndQuic,
}

/// Options for building a node.
#[derive(Debug, Clone)]
pub struct NodeBuildOptions {
    pub transport: TransportConfig,
    pub enable_dns: bool,
    pub enable_identify: bool,
    pub enable_ping: bool,
}

impl Default for NodeBuildOptions {
    fn default() -> Self {
        Self {
            transport: TransportConfig::Tcp,
            enable_dns: true,
            enable_identify: true,
            enable_ping: true,
        }
    }
}

/// Behaviour used by the node.
///
/// Keep this minimal for now; we can extend with:
/// - request-response (1:1 chat)
/// - kad (DHT)
/// - relay v2
/// - gossipsub (groups / announcements)
#[derive(NetworkBehaviour)]
pub struct NodeBehaviour {
    pub ping: ping::Behaviour,
    pub identify: identify::Behaviour,
}

impl NodeBehaviour {
    pub fn new(local_public_key: &identity::PublicKey, opts: &NodeBuildOptions) -> Self {
        let agent_version = format!("echomesh/{}", env!("CARGO_PKG_VERSION"));

        let ping_behaviour = if opts.enable_ping {
            ping::Behaviour::new(ping::Config::new())
        } else {
            // There is no "disabled" behaviour type. Keep ping enabled for now; caller can ignore events.
            ping::Behaviour::new(ping::Config::new())
        };

        let identify_behaviour = if opts.enable_identify {
            identify::Behaviour::new(
                identify::Config::new(agent_version, local_public_key.clone()),
            )
        } else {
            // Same as above: keep identify enabled for now; can be swapped to optional behaviour later.
            identify::Behaviour::new(
                identify::Config::new(agent_version, local_public_key.clone()),
            )
        };

        Self {
            ping: ping_behaviour,
            identify: identify_behaviour,
        }
    }
}

/// Builds libp2p transport according to options.
///
/// Return type is boxed to keep call sites simple and allow swapping transport stacks.
pub fn build_transport(
    keypair: &identity::Keypair,
    opts: &NodeBuildOptions,
) -> Result<Boxed<(PeerId, StreamMuxerBox)>> {
    match opts.transport {
        TransportConfig::Tcp => build_tcp_transport(keypair, opts),
        TransportConfig::Quic => anyhow::bail!("QUIC transport not implemented yet"),
        TransportConfig::TcpAndQuic => anyhow::bail!("TCP+QUIC transport not implemented yet"),
    }
}

/// TCP + Noise + Yamux (+ optionally DNS).
fn build_tcp_transport(
    keypair: &identity::Keypair,
    opts: &NodeBuildOptions,
) -> Result<Boxed<(PeerId, StreamMuxerBox)>> {
    // TCP base transport
    let base_tcp = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true));

    // Optional DNS wrapper (useful on desktop; might be unnecessary/unsupported on some targets)
    let transport = if opts.enable_dns {
        dns::tokio::Transport::system(base_tcp)?.boxed()
    } else {
        base_tcp.boxed()
    };

    // Noise authenticated encryption
    let noise_keys = noise::Config::new(keypair)?;
    // Yamux stream multiplexing
    let yamux_cfg = yamux::Config::default();

    let upgraded = transport
        .upgrade(upgrade::Version::V1)
        .authenticate(noise_keys)
        .multiplex(yamux_cfg)
        .timeout(std::time::Duration::from_secs(20))
        .boxed();

    Ok(upgraded)
}

// ---- Future direction notes ----
//
// 1) QUIC can be added via `libp2p::quic::tokio::Transport` and then combined
//    with TCP using `OrTransport`.
// 2) When we add multiple transports, return `OrTransport<...>` before boxing.
// 3) We may also add `WebRtc`/`Ws` later for web support.
//
// Keep this file focused: transport + behaviour composition happens here,
// not in the FRB API layer.
