//
//  SharePlayView.swift
//  Globes
//
//  Created by BooSung Jung on 31/7/2024.
//

import SwiftUI


struct SharePlayView: View{
    @Environment(ViewModel.self) private var model
    var body: some View{
        VStack{
            Button(action:{
                model.toggleSharePlay()
            },label:{
                Text("Share Play")
            })
        }
        
    }
}

