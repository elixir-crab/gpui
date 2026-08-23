#[cfg(feature = "real-gpui")]
use rustler::Atom;
use rustler::{Binary, Encoder, Env, NifMap, NifResult, ResourceArc, Term};

#[cfg(feature = "real-gpui")]
use futures::{channel::mpsc, StreamExt};
#[cfg(feature = "real-gpui")]
use gpui::Styled;
#[cfg(feature = "real-gpui")]
use std::{
    collections::{HashMap, HashSet},
    sync::{Arc, Mutex},
};
#[cfg(feature = "real-gpui")]
use zed_gpui as gpui;

#[cfg(not(feature = "real-gpui"))]
mod disabled;
mod event;
#[cfg(feature = "real-gpui")]
mod host;
mod image_decode;
#[cfg(feature = "real-gpui")]
mod input;
mod native_test;
#[cfg(feature = "real-gpui")]
mod resource;
mod runtime;
mod text_buffer;
#[cfg(feature = "real-gpui")]
mod window_codec;
#[cfg(not(feature = "real-gpui"))]
use disabled::*;
use event::{
    decode_event_value, encode_native_event, push_event, EventValue, InputKind, NativeEvent,
};
#[cfg(feature = "components")]
use event::{TextCaretGeometry, TextRangeGeometry, TextRectangle, TextViewportGeometry};
#[cfg(feature = "components")]
use event::{TransferEventValue, TransferPayload, MAX_TRANSFER_TEXT_BYTES};
#[cfg(feature = "real-gpui")]
use input::{bind_input_keys, NativeTextInput};
#[cfg(feature = "real-gpui")]
use resource::{decode_raster_resource, decode_resource_ref, ImageData, RasterData};
use runtime::{RuntimeResource, SharedRuntime};
#[cfg(feature = "components")]
use text_buffer::{
    byte_range_to_selection, next_native_transaction_id, position_to_byte_offset,
    selection_to_byte_range,
};
use text_buffer::{TextBufferError, TextBufferResource, TextTransaction};

include!("generated/atoms.rs");
include!("generated/rusty.rs");
include!("generated/runtime_boundary.rs");
include!("generated/test_boundary.rs");
include!("generated/text_types.rs");
include!("generated/event_boundary.rs");
#[cfg(not(feature = "real-gpui"))]
include!("generated/disabled_resource_boundary.rs");
#[cfg(not(feature = "real-gpui"))]
include!("generated/disabled_window.rs");
#[cfg(feature = "real-gpui")]
include!("generated/resource_boundary.rs");
#[cfg(feature = "real-gpui")]
include!("generated/window.rs");
include!("generated/schema.rs");
include!("generated/disabled_nifs.rs");
include!("generated/nifs.rs");

#[cfg(feature = "real-gpui")]
mod element;
mod nif;
#[cfg(feature = "real-gpui")]
mod window;

#[cfg(feature = "real-gpui")]
use element::*;
use nif::*;
#[cfg(feature = "real-gpui")]
use window::*;
#[cfg(feature = "real-gpui")]
use window_codec::*;

rustler::init!("Elixir.GPUI.Native");
