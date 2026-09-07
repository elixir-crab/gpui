use super::*;
use crate::host_contract::{ComponentEventError, ComponentEventSink};
use std::sync::atomic::{AtomicBool, Ordering};

#[derive(Default)]
struct RecordingSink {
    events: Mutex<Vec<ComponentEvent>>,
    fail: AtomicBool,
}

impl ComponentEventSink for RecordingSink {
    fn emit(&self, event: ComponentEvent) -> Result<(), ComponentEventError> {
        if self.fail.load(Ordering::Relaxed) {
            return Err(ComponentEventError::QueueUnavailable);
        }
        self.events.lock().unwrap().push(event);
        Ok(())
    }
}

fn binding(change: Option<&str>) -> SharedBinding<f64> {
    Arc::new(Mutex::new(ControlledBinding::new(
        change.map(str::to_owned),
        0.0,
    )))
}

fn release(name: Option<&str>) -> SharedEvent {
    Arc::new(Mutex::new(name.map(str::to_owned)))
}

fn host() -> (ComponentHost, Arc<RecordingSink>) {
    let sink = Arc::new(RecordingSink::default());
    (ComponentHost::new(sink.clone()), sink)
}

#[test]
fn change_emits_exact_payload_and_reconciles_pending_value() {
    let binding = binding(Some("changed"));
    let (host, sink) = host();
    handle_slider(
        &binding,
        &release(None),
        &host,
        42,
        &SliderEvent::Change(SliderValue::Single(3.5)),
    );
    assert_eq!(
        *sink.events.lock().unwrap(),
        vec![ComponentEvent::Change(ComponentValueEvent {
            envelope: ComponentEventEnvelope {
                window_id: 42,
                event: "changed".into()
            },
            value: ComponentValue::Number(3.5),
        })]
    );
    let mut binding = binding.lock().unwrap();
    assert!(!binding.reconcile(&0.0));
    assert!(!binding.reconcile(&3.5));
    assert!(binding.reconcile(&9.0));
}

#[test]
fn release_only_tracks_value_and_emits_release_payload() {
    let binding = binding(None);
    let (host, sink) = host();
    handle_slider(
        &binding,
        &release(Some("released")),
        &host,
        7,
        &SliderEvent::Release(SliderValue::Range(1.0, 4.0)),
    );
    assert_eq!(
        *sink.events.lock().unwrap(),
        vec![ComponentEvent::Release(ComponentValueEvent {
            envelope: ComponentEventEnvelope {
                window_id: 7,
                event: "released".into()
            },
            value: ComponentValue::Number(4.0),
        })]
    );
    assert!(!binding.lock().unwrap().reconcile(&4.0));
}

#[test]
fn failed_change_rolls_back_only_newest_pending_value() {
    let binding = binding(Some("changed"));
    let (host, sink) = host();
    handle_slider(
        &binding,
        &release(None),
        &host,
        1,
        &SliderEvent::Change(SliderValue::Single(1.0)),
    );
    sink.fail.store(true, Ordering::Relaxed);
    handle_slider(
        &binding,
        &release(None),
        &host,
        1,
        &SliderEvent::Change(SliderValue::Single(2.0)),
    );
    let mut binding = binding.lock().unwrap();
    assert!(!binding.reconcile(&0.0));
    assert!(!binding.reconcile(&1.0));
    assert!(binding.reconcile(&2.0));
    assert_eq!(sink.events.lock().unwrap().len(), 1);
}

#[test]
fn failed_release_only_rolls_back_but_failed_release_after_change_preserves_pending() {
    for change in [None, Some("changed")] {
        let binding = binding(change);
        let (host, sink) = host();
        if change.is_some() {
            handle_slider(
                &binding,
                &release(None),
                &host,
                1,
                &SliderEvent::Change(SliderValue::Single(2.0)),
            );
        }
        sink.fail.store(true, Ordering::Relaxed);
        handle_slider(
            &binding,
            &release(Some("released")),
            &host,
            1,
            &SliderEvent::Release(SliderValue::Single(2.0)),
        );
        assert_eq!(binding.lock().unwrap().reconcile(&2.0), change.is_none());
    }
}

#[test]
fn unbound_events_do_not_emit_or_track_and_release_does_not_duplicate_change() {
    let unbound = binding(None);
    let (host, sink) = host();
    handle_slider(
        &unbound,
        &release(None),
        &host,
        1,
        &SliderEvent::Change(SliderValue::Single(2.0)),
    );
    handle_slider(
        &unbound,
        &release(None),
        &host,
        1,
        &SliderEvent::Release(SliderValue::Single(2.0)),
    );
    assert!(unbound.lock().unwrap().reconcile(&2.0));
    assert!(sink.events.lock().unwrap().is_empty());

    let bound = binding(Some("changed"));
    handle_slider(
        &bound,
        &release(None),
        &host,
        1,
        &SliderEvent::Change(SliderValue::Single(2.0)),
    );
    handle_slider(
        &bound,
        &release(Some("released")),
        &host,
        1,
        &SliderEvent::Release(SliderValue::Single(2.0)),
    );
    let mut bound = bound.lock().unwrap();
    assert!(!bound.reconcile(&2.0));
    assert!(bound.reconcile(&2.0));
    assert_eq!(sink.events.lock().unwrap().len(), 2);
}
