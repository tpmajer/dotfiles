import QtQuick.Effects

// The shadow of the bar and of everything else shaped like it, as the effect
// of an item's layer: `layer.effect: Shadow {}`. It reaches some 30 px around
// the item, which needs that much room in its layer. Text drawn into such a
// layer comes out soft, so it holds the background only.
MultiEffect {
    shadowEnabled: true
    shadowColor: "#77000000"
    shadowBlur: 1.0
    blurMax: 24
    shadowVerticalOffset: 3
}
