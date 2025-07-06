//
//  ContentView.swift
//  ActorHopBenchmark
//  
//  Created by Daiki Fujimori on 2025/07/06
//  

import SwiftUI

// MARK: - ベンチ対象となるデータ構造
/// 1 KB の疑似フレーム
/// ※ 実アプリならUIImageやDataなどを想定
struct Frame {
    // 0 で埋めた 1 KB のバイト列を保持するだけ
    let bytes = [UInt8](repeating: 0, count: 1024)
}

// MARK: - Cache
actor Cache {
    private let f = Frame()
    /// Actor 隔離された通常メソッド = 呼び出し時にhopが発生
    func readWithHop() -> Frame { f }
    
    /// `nonisolated(nonsending)` + `async`
    ///  - 呼び出し側Executorのまま実行される ＝ hopなし
    ///  - note: `async`は必須（そうでないとコンパイルエラー）
    nonisolated(nonsending) func readWithoutHop() async -> Frame { f }
}

// MARK: - SwiftUI画面
struct ContentView: View {
    /// 計測結果を UI に表示するための状態
    @State private var result = "（未計測）"

    var body: some View {
        VStack(spacing: 20) {
            Text("Actor Hop Benchmark")
                .font(.headline)

            // 計測結果ラベル
            Text(result)
                .font(.system(.body, design: .monospaced))

            // ボタンを押すと並列タスクでベンチを実行
            Button("10,000回読み込みを計測") {
                Task.detached { await runBenchmark() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - ベンチマーク本体
    /// hopあり／なしをそれぞれ1万回実行し、計測結果を`@State`変数へ反映
    @MainActor
    private func runBenchmark() async {
        // hopありでの処理時間
        let timeWithHop  = await measure { await Cache().readWithHop()  }
        // hopなしでの処理時間
        let timeWithoutHop = await measure { await Cache().readWithoutHop() }

        // ラベルを更新
        result = """
        hopあり: \(String(format: "%.2f", timeWithHop )) ms
        hopなし: \(String(format: "%.2f", timeWithoutHop)) ms
        """
    }

    // MARK: - 共通計測用関数
    /// 与えられたクロージャを 1 万回`await`し、経過時間をmsで返す
    private func measure(_ work: @escaping () async -> Frame) async -> Double {
        let start = DispatchTime.now()              // 計測開始時刻（ナノ秒精度）
        for _ in 0..<10000 { _ = await work() }    // 処理を1万回呼び出し
        let end = DispatchTime.now()                // 計測終了
        // ns → ms へ変換して返す
        return Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1000000
    }
}

