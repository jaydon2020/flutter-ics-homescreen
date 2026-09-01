import 'package:flutter_ics_homescreen/export.dart';

/// The view size every fixed dimension in this app was drawn against: the
/// assets are 1080x1920 (splashTextures.svg is 1080x1921, BG-dotwaveform.json
/// is 1080x1920), and the screens are built from absolute pixel sizes rather
/// than constraints.
const Size kDesignSize = Size(1080, 1920);

/// Lays the UI out at [kDesignSize] and scales that canvas uniformly to fit the
/// real view, so a display of another size or aspect gets the reference layout
/// shrunk or grown rather than a layout squeezed into the wrong box. Absolute
/// sizes therefore never exceed the space the design gave them, which is what
/// makes widgets stop overlapping on a view the design never anticipated (the
/// dashboard column needs 1454px of height; on a 1080x1440 view it overflowed,
/// on a 1080x1280 one it would overflow further).
///
/// **At the reference size this widget adds nothing at all** — it returns its
/// child untouched, with no transform layer, no `MediaQuery` override and no
/// resampling, so the default configuration renders exactly as it did before
/// this existed. That is a bypass, not a scale of 1.0: a scale-by-one still
/// pushes a transform layer and puts every raster through the sampler.
///
/// When it does scale, text, SVG (flutter_svg), Lottie and Rive are vector and
/// re-rasterize at the scaled size, so they stay sharp; only true raster assets
/// (the BG_Sequence / album-art PNGs) go through the sampler.
///
/// [MediaQuery.size] is rewritten to the design size for the subtree, because a
/// dozen widgets here size themselves from it (`MediaQuery.sizeOf(context)
/// .height * 0.15` and friends) and would otherwise scale twice — once from the
/// real size they read, once from the canvas transform.
class DesignScale extends StatelessWidget {
  const DesignScale({
    super.key,
    required this.child,
    this.designSize = kDesignSize,
    this.letterboxColor = Colors.black,
  });

  final Widget child;

  /// The canvas the UI is laid out on. Defaults to [kDesignSize].
  final Size designSize;

  /// Fills whatever the uniform scale leaves over on the long axis.
  final Color letterboxColor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;

    // Reference view: hand back the child untouched. Also covers a degenerate
    // size (0x0 during a resize), where scaling is meaningless.
    if (size == designSize || size.isEmpty) return child;

    return ColoredBox(
      color: letterboxColor,
      child: MediaQuery(
        // The canvas is exactly the design size, and it is centred rather than
        // inset, so the padding/inset a real view reports does not apply to it.
        data: media.copyWith(
          size: designSize,
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
        ),
        // FittedBox, not Transform.scale over a SizedBox: a SizedBox cannot
        // exceed the constraints handed to it, so on a 1920x720 view it would
        // be clamped to 1080x720 and the canvas would be squeezed — the very
        // thing this widget exists to prevent. FittedBox lays its child out
        // unbounded, then scales the result to fit.
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox.fromSize(size: designSize, child: child),
        ),
      ),
    );
  }
}
