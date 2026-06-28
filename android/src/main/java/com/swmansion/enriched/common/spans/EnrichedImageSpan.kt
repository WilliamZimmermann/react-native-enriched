package com.swmansion.enriched.common.spans

import android.content.res.Resources
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.graphics.drawable.AnimatedImageDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.Spannable
import android.text.style.ImageSpan
import android.util.Log
import androidx.core.graphics.drawable.toDrawable
import androidx.core.graphics.withSave
import com.swmansion.enriched.common.AsyncDrawable
import com.swmansion.enriched.common.ForceRedrawSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan
import java.io.File

open class EnrichedImageSpan :
  ImageSpan,
  EnrichedInlineSpan {
  private var width: Int = 0
  private var height: Int = 0

  /** Optional caption shown below the image; round-trips as `data-caption`. */
  var caption: String? = null

  constructor(drawable: Drawable, source: String, width: Int, height: Int) : super(drawable, source, ALIGN_BASELINE) {
    this.width = width
    this.height = height
  }

  private val captionPaint: Paint by lazy {
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      val density = Resources.getSystem().displayMetrics.density
      textSize = 13f * density
      color = 0xFF8A8A8A.toInt()
    }
  }

  private fun captionDensityGap(): Float = 4f * Resources.getSystem().displayMetrics.density

  /** Vertical space (px) the caption needs below the image baseline, or 0. */
  private fun captionExtraHeight(): Int {
    val cap = caption
    if (cap.isNullOrBlank()) return 0
    val fm = captionPaint.fontMetricsInt
    return captionDensityGap().toInt() + (fm.descent - fm.ascent)
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence?,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    val drawable = drawable
    val cap = caption
    canvas.withSave {
      val transY =
        if (cap.isNullOrBlank()) {
          // Original behavior: image bottom rests on the line bottom.
          (bottom - drawable.bounds.bottom - paint.fontMetricsInt.descent).toFloat()
        } else {
          // With a caption, anchor the image bottom on the text baseline so the
          // caption can sit in the reserved descent space below it.
          (y - drawable.bounds.bottom).toFloat()
        }
      translate(x, transY)
      drawable.draw(this)
    }

    // NOTE: native caption rendering is best-effort and needs on-device tuning.
    if (!cap.isNullOrBlank()) {
      val cp = captionPaint
      val captionBaseline = y + captionDensityGap() - cp.fontMetricsInt.ascent
      val imgWidth = drawable.bounds.right.toFloat()
      val textWidth = cp.measureText(cap)
      val tx = x + (if (imgWidth > textWidth) (imgWidth - textWidth) / 2f else 0f)
      canvas.drawText(cap, tx, captionBaseline, cp)
    }
  }

  override fun getDrawable(): Drawable {
    val drawable = super.getDrawable()
    val (w, h) = effectiveBounds(drawable)

    drawable.setBounds(0, 0, w, h)
    return drawable
  }

  /**
   * Returns the pixel size at which the image should render.
   *
   * When the author supplied real dimensions (`width > 0 && height > 0`) we keep
   * the existing behavior: convert the dp attributes to px using the display
   * density.
   *
   * Web-authored notes store `<img width="0" height="0">` and let CSS size the
   * image. With no usable author dimensions the editor would draw the image at
   * 0×0 (invisible), so once the drawable has loaded we adopt its intrinsic
   * pixel size, capped to the device width (preserving aspect ratio) so a large
   * image never overflows. Intrinsic size is -1 until the async load finishes;
   * we return 0×0 until then and rely on the load callback to re-measure.
   */
  private fun effectiveBounds(d: Drawable): Pair<Int, Int> {
    if (width > 0 && height > 0) {
      val scale = Resources.getSystem().displayMetrics.density
      return Pair((width * scale).toInt(), (height * scale).toInt())
    }

    var iw = d.intrinsicWidth
    var ih = d.intrinsicHeight
    if (iw <= 0 || ih <= 0) {
      // Not loaded yet — stay 0×0; observeAsyncDrawableLoaded() triggers a
      // re-measure once the intrinsic size is known.
      return Pair(0, 0)
    }

    val maxW = Resources.getSystem().displayMetrics.widthPixels
    if (maxW > 0 && iw > maxW) {
      ih = (ih.toLong() * maxW / iw).toInt()
      iw = maxW
    }
    return Pair(iw, ih)
  }

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    val d = drawable
    val rect = d.bounds

    if (fm != null) {
      val imageHeight = rect.bottom - rect.top

      // We want the image bottom to sit on the baseline (0).
      // Therefore, the image top will be at: -imageHeight.
      val targetTop = -imageHeight

      // Expand the line UPWARDS if the image is taller than the current font
      if (targetTop < fm.ascent) {
        fm.ascent = targetTop
        fm.top = targetTop
      }

      // Reserve space BELOW the baseline for the caption (rendered in draw()).
      val extra = captionExtraHeight()
      if (extra > 0) {
        if (fm.descent < extra) fm.descent = extra
        if (fm.bottom < extra) fm.bottom = extra
      }
    }

    return rect.right
  }

  private fun registerDrawableLoadCallback(
    d: AsyncDrawable,
    text: Spannable?,
  ) {
    d.onLoaded = onLoaded@{
      val spannable = text

      if (spannable == null) {
        return@onLoaded
      }
      // Ensure we are on the Main Thread before modifying the Spannable
      Handler(Looper.getMainLooper()).post {
        val start = spannable.getSpanStart(this@EnrichedImageSpan)
        val end = spannable.getSpanEnd(this@EnrichedImageSpan)

        if (start != -1 && end != -1) {
          // trick for adding empty span to force redraw when image is loaded
          val redrawSpan = ForceRedrawSpan()
          spannable.setSpan(redrawSpan, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
          spannable.removeSpan(redrawSpan)
        }
      }
    }
  }

  fun observeAsyncDrawableLoaded(text: Spannable?) {
    val d = drawable

    if (d !is AsyncDrawable) {
      return
    }

    registerDrawableLoadCallback(d, text)

    // If it's already loaded (race condition), run logic immediately
    if (d.isLoaded) {
      d.onLoaded?.invoke()
    }
  }

  fun getWidth(): Int = width

  fun getHeight(): Int = height

  companion object {
    fun prepareDrawableForImage(
      src: String,
      width: Int,
      height: Int,
    ): Drawable? {
      var cleanPath = src

      if (cleanPath.startsWith("http://") || cleanPath.startsWith("https://")) {
        return AsyncDrawable(cleanPath)
      }

      if (cleanPath.startsWith("file://")) {
        cleanPath = cleanPath.substring(7)
      }

      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
        return try {
          val bitmap = BitmapFactory.decodeFile(cleanPath) ?: return null
          val drawable = bitmap.toDrawable(Resources.getSystem())
          drawable.setBounds(0, 0, bitmap.width, bitmap.height)
          return drawable
        } catch (e: Exception) {
          Log.e("EnrichedImageSpan", "Failed to load legacy image: $cleanPath", e)
          null
        }
      }

      return try {
        val file = File(cleanPath)
        val source = ImageDecoder.createSource(file)

        val density = Resources.getSystem().displayMetrics.density
        val targetWidthPx = (width * density).toInt()
        val targetHeightPx = (height * density).toInt()

        val drawable =
          ImageDecoder.decodeDrawable(source) { decoder, info, source ->
            decoder.setTargetSize(targetWidthPx, targetHeightPx)
          }

        if (drawable is AnimatedImageDrawable) {
          drawable.setBounds(0, 0, drawable.intrinsicWidth, drawable.intrinsicHeight)
          drawable.repeatCount = AnimatedImageDrawable.REPEAT_INFINITE
          drawable.start()
        }
        drawable
      } catch (e: Exception) {
        Log.e("EnrichedImageSpan", "Failed to load image: $cleanPath", e)
        null
      }
    }
  }
}
