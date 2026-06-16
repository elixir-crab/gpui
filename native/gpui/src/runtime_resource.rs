use crate::events::NativeEvent;
use std::sync::Mutex;

#[cfg(feature = "real-gpui")]
use crate::{RasterData, SharedWindow};
#[cfg(feature = "real-gpui")]
use std::collections::HashMap;

pub struct RuntimeResource {
    pub(crate) events: Mutex<Vec<NativeEvent>>,
    #[cfg(feature = "real-gpui")]
    pub(crate) windows: Mutex<HashMap<u64, SharedWindow>>,
    #[cfg(feature = "real-gpui")]
    pub(crate) resources: Mutex<HashMap<String, RasterData>>,
    #[cfg(feature = "real-gpui")]
    pub(crate) input_values: Mutex<HashMap<String, String>>,
}

#[rustler::resource_impl]
impl rustler::Resource for RuntimeResource {}

impl RuntimeResource {
    pub(crate) fn new() -> Self {
        Self {
            events: Mutex::new(Vec::new()),
            #[cfg(feature = "real-gpui")]
            windows: Mutex::new(HashMap::new()),
            #[cfg(feature = "real-gpui")]
            resources: Mutex::new(HashMap::new()),
            #[cfg(feature = "real-gpui")]
            input_values: Mutex::new(HashMap::new()),
        }
    }
}
