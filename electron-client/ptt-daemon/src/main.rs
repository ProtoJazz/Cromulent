use evdev::{Device, Key};
use std::io::{self, Write};

fn main() -> io::Result<()> {
    eprintln!("PTT Daemon starting...");
    
    // Find keyboard devices
    let devices: Vec<Device> = evdev::enumerate()
        .map(|(_, device)| device)
        .filter(|d| {
            d.supported_keys()
                .map_or(false, |keys| keys.contains(Key::KEY_LEFTCTRL))
        })
        .collect();
    
    if devices.is_empty() {
        eprintln!("No keyboard devices found!");
        return Ok(());
    }
    
    eprintln!("Found {} keyboard device(s)", devices.len());
    
    // Listen to first keyboard
    let mut device = devices.into_iter().next().unwrap();
    eprintln!("Listening on: {}", device.name().unwrap_or("Unknown"));
    
    loop {
        for event in device.fetch_events()? {
            // Only care about key events
            if let evdev::InputEventKind::Key(key) = event.kind() {
                let state = match event.value() {
                    0 => "UP",
                    1 => "DOWN",
                    2 => "REPEAT",
                    _ => "UNKNOWN",
                };
                
                // Print to stdout (Electron will read this)
                println!("KEY:{}:{}", key.code(), state);
                io::stdout().flush()?;
            }
        }
    }
}