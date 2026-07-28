use rustler::{Atom, Binary, Encoder, Env, NifResult, ResourceArc, Term};

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

mod event;
#[cfg(feature = "real-gpui")]
mod host;
mod image_decode;
#[cfg(feature = "real-gpui")]
mod input;
#[cfg(feature = "real-gpui")]
mod resource;
mod runtime;
mod text_buffer;
#[cfg(any(feature = "components", feature = "real-gpui"))]
use event::EventValue;
use event::{decode_event_value, encode_native_event, push_event, InputKind, NativeEvent};
#[cfg(feature = "real-gpui")]
use input::{bind_input_keys, NativeTextInput};
#[cfg(feature = "real-gpui")]
use resource::{decode_raster_resource, decode_resource_ref, ImageData, RasterData};
use runtime::{RuntimeResource, SharedRuntime};
#[cfg(feature = "components")]
use text_buffer::{byte_range_to_selection, next_native_transaction_id, selection_to_byte_range};
use text_buffer::{TextBufferError, TextBufferResource, TextSelection, TextTransaction};

include!("generated/atoms.rs");
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

rustler::init!("Elixir.GPUI.Native");
