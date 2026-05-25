//! wf-themes-host — Firefox native messaging host.

use anyhow::Result;
use serde_json::{Value, json};
use std::io::{Read, Write, stdin, stdout};

/// Write one message to stdout in Firefox's native messaging wire format:
/// 4-byte native-endian length prefix followed by UTF-8 JSON.
fn write_msg(msg: &Value) -> Result<()> {
    let payload = serde_json::to_vec(msg)?;
    let len = u32::try_from(payload.len())?;
    let mut out = stdout().lock();
    out.write_all(&len.to_ne_bytes())?;
    out.write_all(&payload)?;
    out.flush()?;
    Ok(())
}

/// Read one message from stdin. Returns Ok(None) on clean EOF (Firefox
/// disconnected).
#[allow(dead_code)]
fn read_msg() -> Result<Option<Value>> {
    let mut len_buf = [0u8; 4];
    let mut input = stdin().lock();
    match input.read_exact(&mut len_buf) {
        Ok(()) => {}
        Err(e) if e.kind() == std::io::ErrorKind::UnexpectedEof => return Ok(None),
        Err(e) => return Err(e.into()),
    }
    let len = u32::from_ne_bytes(len_buf) as usize;
    let mut buf = vec![0u8; len];
    input.read_exact(&mut buf)?;
    Ok(Some(serde_json::from_slice(&buf)?))
}

fn main() -> Result<()> {
    // Smoke test: send a hardcoded theme so we can verify wire format end-to-end
    // before adding the wmenu reader.
    write_msg(&json!({ "theme": "paper" }))?;
    Ok(())
}
