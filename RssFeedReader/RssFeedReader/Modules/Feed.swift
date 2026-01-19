import Foundation

struct Feed: Identifiable, Hashable {
    var id: String { url }
    let url: String
    let limit : Int?
}
