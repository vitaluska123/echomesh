//! Transport construction helpers.
//!
//! Today: TCP + Noise + Yamux
//! Future: add QUIC (and optionally combine TCP+QUIC).
//!
//! This file intentionally contains only transport wiring logic. Behaviour and
//! swarm logic should live elsewhere.

use anyhow::{bail, Context, Result};
use libp2p::{
    core::{
        muxing::StreamMuxerBox,
        transport::Boxed,
        upgrade::{self, Version},
    },
    dns, identity, noise, tcp, yamux, PeerId, Transport,
};
use std::time::Duration;

/// Build the libp2p transport stack.
/// - `enable_quic=false`: TCP + Noise + Yamux (+ DNS)
/// - `enable_quic=true`: currently returns an error (extension point)
///
/// Note: We always enable DNS right now for better desktop dev UX.
/// If you hit platform issues on Android, add a flag to disable it.
pub fn build_transport(
    keypair: &identity::Keypair,
    enable_quic: bool,
) -> Result<Boxed<(PeerId, StreamMuxerBox)>> {
    if enable_quic {
        // Extension point: switch to `libp2p::quic::tokio::Transport` and combine
        // with TCP via `OrTransport` when we implement QUIC support.
        bail!("QUIC transport not implemented yet (enable_quic=true)");
    }

    build_tcp_transport(keypair)
}

/// TCP + (optional DNS) + Noise + Yamux.
///
/// This is the most boring, stable transport to get MVP running.
/// Later we can add:
/// - QUIC
/// - websocket/webrtc (for web)
/// - relay / proxy stacks
fn build_tcp_transport(keypair: &identity::Keypair) -> Result<Boxed<(PeerId, StreamMuxerBox)>> {
    // TCP base transport.
    let tcp_transport = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true));

    // DNS wrapper (helps resolving /dns4/... multiaddrs etc).
    // If this fails on some platforms, we can make it optional.
    let transport = dns::tokio::Transport::system(tcp_transport)
        .context("failed to construct DNS-over-TCP transport")?
        .boxed();

    // Noise authenticated encryption.
    // `noise::Config::new` uses the provided identity keypair to authenticate.
    let noise_config = noise::Config::new(keypair).context("failed to create Noise config")?;

    // Yamux stream multiplexer.
    let yamux_config = yamux::Config::default();

    // Upgrade stack.
    let upgraded = transport
        .upgrade(Version::V1)
        .authenticate(noise_config)
        .multiplex(yamux_config)
        .timeout(Duration::from_secs(20))
        .boxed();

    Ok(upgraded)
}
