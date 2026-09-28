//
//  HolaESCOMApp.swift
//  HolaESCOM — Proyecto de prueba del Ejercicio 1 (Práctica 3)
//
//  Verifica que el entorno macOS + Xcode + simulador de iOS funciona:
//  muestra información del dispositivo/simulador y un contador con estado.
//

import SwiftUI

@main
struct HolaESCOMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var taps = 0
    @AppStorage("temaAzul") private var temaAzul = false

    private var colorTema: Color {
        temaAzul ? Color(red: 0.0, green: 0.36, blue: 0.62) : Color(red: 0.44, green: 0.11, blue: 0.27)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "swift")
                            .font(.system(size: 64))
                            .foregroundStyle(colorTema)
                        Text("¡Hola, ESCOM!")
                            .font(.largeTitle.bold())
                        Text("Entorno de desarrollo iOS verificado")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }

                Section("Información del entorno") {
                    LabeledContent("Dispositivo", value: UIDevice.current.model)
                    LabeledContent("Sistema", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                    #if targetEnvironment(simulator)
                    LabeledContent("Ejecución", value: "Simulador")
                    #else
                    LabeledContent("Ejecución", value: "Dispositivo físico")
                    #endif
                    LabeledContent("Swift", value: swiftVersion)
                }

                Section("Prueba de estado") {
                    Button {
                        withAnimation(.spring) { taps += 1 }
                    } label: {
                        Label("Toques: \(taps)", systemImage: "hand.tap.fill")
                    }
                    Toggle("Tema Azul ESCOM", isOn: $temaAzul)
                }
            }
            .navigationTitle("Práctica 3")
            .tint(colorTema)
        }
    }

    private var swiftVersion: String {
        #if swift(>=6.0)
        return "6.x"
        #elseif swift(>=5.9)
        return "5.9+"
        #else
        return "5.x"
        #endif
    }
}

#Preview {
    ContentView()
}
