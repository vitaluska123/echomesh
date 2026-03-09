use flutter_rust_bridge::frb;
use libp2p::PeerId;
use anyhow::Result;

#[frb]
pub async fn generate_peer_id() -> Result<String> {
    let peer_id = PeerId::random();
    Ok(peer_id.to_string())
}
