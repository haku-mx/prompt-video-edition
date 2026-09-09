//
//  HakuApp.swift
//  Haku — edición de video por prompts en lenguaje natural.
//
//  Punto de entrada de la app iOS (SwiftUI). La app es un cliente delgado del
//  servidor FastAPI (ver PLAN.md → "Track iOS"): nunca corre visión ni toca
//  video, solo habla con `server/` por HTTP.
//

import SwiftUI

@main
struct HakuApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
    }
}
