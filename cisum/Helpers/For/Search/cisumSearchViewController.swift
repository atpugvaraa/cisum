//
//  cisumSearchViewController.swift
//  cisum
//
//  Created by Aarav Gupta on 15/05/25.
//

import SwiftUI
import UIKit

struct cisumSearchViewController: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Artists, Songs, Lyrics, and More"
    @Binding var isSearching: Bool // binding for focus animations

    class Coordinator: NSObject, UISearchBarDelegate {
        var parent: cisumSearchViewController

        init(_ parent: cisumSearchViewController) {
            self.parent = parent
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            withAnimation(.easeInOut) {
                parent.isSearching = true
            }

            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: {
                searchBar.setShowsCancelButton(true, animated: true)
            }, completion: nil)
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            
        }


        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            parent.text = ""
            withAnimation(.easeInOut) {
                parent.isSearching = false
            }
            
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: {
                searchBar.setShowsCancelButton(false, animated: true)
            }, completion: { _ in
                searchBar.resignFirstResponder()
            })
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = placeholder
        searchBar.autocapitalizationType = .none

        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.layer.cornerRadius = 10
            textField.layer.masksToBounds = true
            textField.backgroundColor = UIColor.systemBackground

            // Subtle shadow
            textField.layer.shadowColor = UIColor.black.cgColor
            textField.layer.shadowOpacity = 0.1
            textField.layer.shadowOffset = CGSize(width: 0, height: 2)
            textField.layer.shadowRadius = 4
            
            // Add shadowPath to optimize shadow rendering
            textField.layer.shadowPath = UIBezierPath(roundedRect: textField.bounds, cornerRadius: textField.layer.cornerRadius).cgPath
            
            // Removes inner "x" clear button
            textField.clearButtonMode = .never
        }

        return searchBar
    }


    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text

        guard let textField = uiView.value(forKey: "searchField") as? UITextField else { return }

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            if isSearching {
                textField.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
                textField.layer.shadowOpacity = 0.25
            } else {
                textField.transform = .identity
                textField.layer.shadowOpacity = 0.1
            }
            
            // Update shadowPath to match current bounds during animation
            let scale = isSearching ? 1.02 : 1.0
            let scaledBounds = CGRect(x: 0, y: 0, width: textField.bounds.width * scale, height: textField.bounds.height * scale)
            textField.layer.shadowPath = UIBezierPath(roundedRect: scaledBounds, cornerRadius: textField.layer.cornerRadius).cgPath
        }
    }

}
