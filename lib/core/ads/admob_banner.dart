import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:metroeye_flutter/core/ads/admob_config.dart';
import 'package:metroeye_flutter/core/theme/app_colors.dart';

class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key, required this.placement});

  final AdMobBannerPlacement placement;

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  int? _adWidth;
  bool _isLoading = false;
  bool _isLoaded = false;

  @override
  void didUpdateWidget(covariant AdMobBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _disposeAd();
      _adWidth = null;
    }
  }

  @override
  void dispose() {
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.truncate();
        if (width > 0 && width != _adWidth && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadAd(width);
          });
        }

        final bannerAd = _bannerAd;
        final adSize = _adSize;
        if (!_isLoaded || bannerAd == null || adSize == null) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.gray2)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: adSize.height.toDouble(),
              child: Center(
                child: SizedBox(
                  width: adSize.width.toDouble(),
                  height: adSize.height.toDouble(),
                  child: AdWidget(ad: bannerAd),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAd(int width) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _adWidth = width;
      _isLoading = true;
      _isLoaded = false;
    });

    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width) ??
        AdSize.banner;
    if (!mounted) {
      return;
    }

    final bannerAd = BannerAd(
      adUnitId: AdMobConfig.bannerAdUnitId(widget.placement),
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = adSize;
            _isLoading = false;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) {
            return;
          }

          setState(() {
            _bannerAd = null;
            _adSize = null;
            _isLoading = false;
            _isLoaded = false;
          });
        },
      ),
    );

    await bannerAd.load();
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _adSize = null;
    _isLoading = false;
    _isLoaded = false;
  }
}
