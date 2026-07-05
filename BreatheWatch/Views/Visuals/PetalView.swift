import SwiftUI

struct PetalView: View {
    var color: Color
    var scale: CGFloat
    var rotationOffset: Angle = .zero
    
    let petalCount = 6
    
    var body: some View {
        ZStack {
            ForEach(0..<petalCount, id: \.self) { index in
                let angle = Angle.degrees(Double(index) * (360.0 / Double(petalCount)))
                Circle()
                    .fill(color.opacity(0.35).gradient)
                    .frame(width: 55, height: 55)
                    // Offset moves the petal out from the center based on scale
                    .offset(y: -22 * scale)
                    .rotationEffect(angle + rotationOffset)
                    .blendMode(.screen)
            }
        }
        .frame(width: 120, height: 120)
        .scaleEffect(scale)
    }
}
