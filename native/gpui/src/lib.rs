use rustler::{Atom, Encoder, Env, NifResult, ResourceArc, Term};

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
mod input;
#[cfg(feature = "real-gpui")]
mod resource;
mod runtime;
use event::{encode_native_event, push_event, EventValue, InputKind, NativeEvent};
#[cfg(feature = "real-gpui")]
use input::{bind_input_keys, NativeTextInput};
#[cfg(feature = "real-gpui")]
use resource::{decode_raster_resource, decode_resource_ref, ImageData, RasterData};
use runtime::{RuntimeResource, SharedRuntime};

include!("generated/atoms.rs");
include!("generated/schema.rs");
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
