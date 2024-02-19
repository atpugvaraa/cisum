//
//  Block1.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//

import SwiftUI

struct Block1: View {
    var body: some View {
        ScrollView(.vertical , showsIndicators: false){
            VStack{
                ZStack {
                    
                    VStack{
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("".uppercased())
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Music").fontWeight(.bold).font(.title3)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("The new music that matters").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                        })
                        .padding(.bottom)
                        
                        ZStack{
                            Image("Radio-4")
                                .resizable()
                                .scaledToFill()
                                .cornerRadius(20)
                                .frame(width: 350 , height: 232)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .frame(width: 350 , height: 72)
                                .offset(y: 95)
                                .foregroundStyle(Color.gray.gradient)
                                .opacity(0.9)
                            VStack {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Live 11:30AM - 1:30PM".uppercased())
                                            .font(.caption2)
                                        Text("Young Money radio")
                                            .font(.callout)
                                            .bold()
                                        Text("A fusion of reggae , uptemp, and classic sound").font(.caption)
                                        
                                    }.multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.primary)
                                }.padding(.horizontal)
                                    .offset(y: 94)
                            }
                        }
                    }
                    .frame(width: 350 , height: 350)
                }
                
                ZStack {
                    
                    VStack{
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Music Hts").fontWeight(.bold).font(.title3)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Songs you know and love").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                        })
                        .padding(.bottom)
                        
                        ZStack{
                            Image("Radio-6")
                                .resizable()
                                .scaledToFill()
                                .cornerRadius(20)
                                .frame(width: 350 , height: 232)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .frame(width: 350 , height: 72)
                                .offset(y: 95)
                                .foregroundStyle(Color.pink)
                                .opacity(0.9)
                            VStack {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Live 8:30AM - 1:30PM".uppercased())
                                            .font(.caption2)
                                        Text("2000 Hits Essentails")
                                            .font(.callout)
                                            .bold()
                                        Text("The idols and pop stars from the 21st century").font(.caption)
                                        
                                    }.multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.primary)
                                }.padding(.horizontal)
                                    .offset(y: 94)
                            }
                        }
                    }
                    .frame(width: 350 , height: 350)
                }
                
                ZStack {
                    
                    VStack{
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Smooth Jazz").fontWeight(.bold).font(.title3)
                            Spacer()
                        })
                        
                        
                        HStack(alignment: .center,spacing: 0 ,content: {
                            Text("Where it sounds like home").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                        })
                        .padding(.bottom)
                        
                        ZStack{
                            Image("Radio-5")
                                .resizable()
                                .scaledToFill()
                                .cornerRadius(20)
                                .frame(width: 350 , height: 232)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .frame(width: 350 , height: 72)
                                .offset(y: 95)
                                .foregroundStyle(Color.blue.gradient)
                                .opacity(0.9)
                            VStack {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Live 1:30AM - 1:30PM".uppercased())
                                            .font(.caption2)
                                        Text("Jazz - Love")
                                            .font(.callout)
                                            .bold()
                                        Text("New jazz discoveries making waves").font(.caption)
                                        
                                    }.multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                    Button(action: {}, label: {
                                        Image(systemName: "play.circle.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.primary)
                                    })
                                }.padding(.horizontal)
                                    .offset(y: 94)
                            }
                        }
                    }
                    .frame(width: 350 , height: 350)
                }
                
            }
        }
        .padding(.horizontal)
        .scrollClipDisabled()
        .scrollTargetBehavior(.paging)
    }
}

#Preview {
    Block1()
}
