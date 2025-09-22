//
//  ContentView.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/21/25.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,            
                photoLibrary: .shared()
            ) {
                Label("앨범에서 사진 선택", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            } else {
                Text("선택된 이미지가 없습니다")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    self.image = uiImage
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
