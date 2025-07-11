//
//  DisplayView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 11/07/2025.
//

import SwiftUI

struct DisplayView: View {
    @Binding var text: String
    var body: some View {
        ZStack {
            Rectangle()
                .frame(height: 75)
                .foregroundStyle(.black)
            Text(text)
                .foregroundColor(.white)
                .font(.title)
                .background(.black)
        }
        .padding(.bottom, 5)
    }
}
