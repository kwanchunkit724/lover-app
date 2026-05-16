package michel.kit.us.ui.components

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp

/**
 * Asymmetric speech bubble — rounded everywhere except the bottom corner
 * closest to the avatar side (the "tail" corner). 18dp big / 6dp small.
 *
 * Port of ios/.../MessageBubble.swift `BubbleShape` (UnevenRoundedRectangle).
 */
object BubbleShape {
    private val big = 18.dp
    private val small = 6.dp

    fun forSender(isFromMe: Boolean): Shape =
        if (isFromMe) {
            // Tail on bottom-right (the side adjacent to "my" edge).
            RoundedCornerShape(topStart = big, topEnd = big, bottomStart = big, bottomEnd = small)
        } else {
            // Tail on bottom-left.
            RoundedCornerShape(topStart = big, topEnd = big, bottomStart = small, bottomEnd = big)
        }
}
