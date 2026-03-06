use evdev::{Device, Key};
use std::io::{self, Write};

fn main() -> io::Result<()> {
    let args: Vec<String> = std::env::args().collect();

    // --list: print available keyboard devices as JSON and exit
    if args.contains(&"--list".to_string()) {
        return list_devices();
    }

    // Optional positional arg: /dev/input/eventN
    let device_path = args.get(1).filter(|a| !a.starts_with("--")).cloned();

    eprintln!("PTT Daemon starting...");

    let mut device = if let Some(ref path) = device_path {
        eprintln!("Opening device: {}", path);
        Device::open(path).map_err(|e| {
            eprintln!("Failed to open {}: {}", path, e);
            e
        })?
    } else {
        // Auto-detect: first keyboard that has KEY_LEFTCTRL
        let devices: Vec<Device> = evdev::enumerate()
            .map(|(_, d)| d)
            .filter(|d| {
                d.supported_keys()
                    .map_or(false, |keys| keys.contains(Key::KEY_LEFTCTRL))
            })
            .collect();

        if devices.is_empty() {
            eprintln!("No keyboard devices found!");
            return Ok(());
        }

        eprintln!("Found {} keyboard device(s), using first", devices.len());
        devices.into_iter().next().unwrap()
    };

    eprintln!("Listening on: {}", device.name().unwrap_or("Unknown"));

    loop {
        for event in device.fetch_events()? {
            if let evdev::InputEventKind::Key(key) = event.kind() {
                let state = match event.value() {
                    0 => "UP",
                    1 => "DOWN",
                    2 => "REPEAT",
                    _ => "UNKNOWN",
                };
                println!("KEY:{}:{}", key.code(), state);
                io::stdout().flush()?;
            }
        }
    }
}

fn list_devices() -> io::Result<()> {
    let mut entries: Vec<serde_json::Value> = evdev::enumerate()
        .filter_map(|(path, device)| {
            // Only include devices that look like keyboards (have KEY_LEFTCTRL or KEY_A)
            let keys = device.supported_keys()?;
            if !keys.contains(Key::KEY_LEFTCTRL) && !keys.contains(Key::KEY_A) {
                return None;
            }
            let name = device.name().unwrap_or("Unknown").to_string();
            let path_str = path.to_string_lossy().to_string();
            Some(serde_json::json!({ "path": path_str, "name": name }))
        })
        .collect();

    // Stable sort by path
    entries.sort_by(|a, b| {
        a["path"].as_str().unwrap_or("").cmp(b["path"].as_str().unwrap_or(""))
    });

    println!("{}", serde_json::to_string(&entries).unwrap_or_else(|_| "[]".to_string()));
    io::stdout().flush()?;
    Ok(())
}
