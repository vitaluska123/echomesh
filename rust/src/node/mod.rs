//! libp2p node module (TCP-first, QUIC-ready).
//!
//! Keep this module as a small façade:
//! - transport construction + behaviour composition: `builder`
//! - background swarm loop + status events: `swarm_task`
//! - process-wide lifecycle control (singleton): `manager`
//!
//! The FRB API layer should call into `manager` and only expose plain data types
//! (strings/bools) across the FFI boundary.

pub mod builder;
pub mod swarm_task;
pub mod manager;
pub mod transport;

// Common re-exports for convenience at call sites.
pub use builder::{NodeBehaviour, NodeBuildOptions, TransportConfig};
pub use manager::{global as global_node_manager, NodeManager, NodeStatus};
pub use swarm_task::{NodeConfig, NodeEvent, SpawnedNode};
