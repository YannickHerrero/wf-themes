//! wf-themes-host — Firefox native messaging host.

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::{Value, json};
use std::io::{Read, Write, stdin, stdout};
use std::path::{Path, PathBuf};

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

/// We only care about the theme field; wmenu's config has many others.
#[derive(Deserialize)]
struct WmenuConfig {
    theme: String,
}

fn config_path() -> Result<PathBuf> {
    let dir = dirs::config_dir().context("no XDG config dir")?;
    Ok(dir.join("wmenu").join("config.toml"))
}

fn read_theme(path: &Path) -> Result<String> {
    let text = std::fs::read_to_string(path)
        .with_context(|| format!("read {}", path.display()))?;
    let cfg: WmenuConfig =
        toml::from_str(&text).with_context(|| format!("parse {}", path.display()))?;
    Ok(cfg.theme)
}

fn main() -> Result<()> {
    let path = config_path()?;
    let theme = read_theme(&path)?;
    eprintln!("wf-themes-host: pushing initial theme={}", theme);
    write_msg(&json!({ "theme": theme }))?;
    Ok(())
}
