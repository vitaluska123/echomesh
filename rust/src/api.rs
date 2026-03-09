use anyhow::Result;
use flutter_rust_bridge::frb;
use libp2p::PeerId;

use crate::node::{global_node_manager, NodeConfig};

#[frb]
pub async fn generate_peer_id() -> Result<String> {
    let peer_id = PeerId::random();
    Ok(peer_id.to_string())
}

#[frb]
pub async fn node_start(listen_addr: String, enable_quic: bool) -> Result<String> {
    let listen_addr = listen_addr.parse()?;
    let config = NodeConfig {
        listen_addr,
        node_name: None,
        enable_quic,
    };

    global_node_manager().start(config).await
}

#[frb]
pub fn node_stop() -> Result<()> {
    global_node_manager().stop()
}

#[frb]
pub fn node_peer_id() -> Result<Option<String>> {
    global_node_manager().peer_id()
}

#[frb]
pub fn node_status() -> Result<(bool, Option<String>, Vec<String>)> {
    let status = global_node_manager().status()?;
    Ok((status.running, status.peer_id, status.listen_addrs))
}
