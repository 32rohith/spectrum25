package com.example.specturmapp

import androidx.multidex.MultiDexApplication

// This class is needed to enable MultiDex for the app
class MultidexApplication : MultiDexApplication() {
    // Flutter initialization is handled by the FlutterActivity
    // No need to manually initialize Flutter here
} 