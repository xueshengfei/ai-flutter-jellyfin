import 'package:flutter/material.dart';

/// AI 推荐入口胶囊动画按钮
///
/// 放在 AppBar actions 中，点击 [onPressed] 跳转到 AI 推荐页面。
/// 动画周期 9 秒：圆形 → 展开胶囊显示「AI 推荐」→ 收回 → 静止。
class AiRecommendPill extends StatefulWidget {
  final VoidCallback onPressed;
  const AiRecommendPill({super.key, required this.onPressed});

  @override
  State<AiRecommendPill> createState() => _AiRecommendPillState();
}

class _AiRecommendPillState extends State<AiRecommendPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// 总周期 9 秒：
  /// 0.0–0.06  (0–0.5s)   展开圆形 → 胶囊
  /// 0.06–0.72 (0.5–6.5s) 胶囊态展示「AI 推荐」
  /// 0.72–0.78 (6.5–7s)   收回胶囊 → 圆形
  /// 0.78–1.0  (7–9s)     圆形静止等待
  static const _totalMs = 9000;
  static const _expandEnd = 0.06;
  static const _holdEnd = 0.72;
  static const _shrinkEnd = 0.78;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );
    // 延迟 2 秒后启动循环动画
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 展开/收回进度 0→1→0
  double _widthProgress(double t) {
    if (t < _expandEnd) {
      return Curves.easeOutCubic.transform(t / _expandEnd);
    } else if (t < _holdEnd) {
      return 1.0;
    } else if (t < _shrinkEnd) {
      return 1.0 - Curves.easeInCubic.transform((t - _holdEnd) / (_shrinkEnd - _holdEnd));
    }
    return 0.0;
  }

  /// 文字透明度：展开后半段淡入，收回前半段淡出
  double _textOpacity(double t) {
    if (t < _expandEnd * 0.6) return 0.0;
    if (t < _expandEnd) {
      return Curves.easeOut.transform((t - _expandEnd * 0.6) / (_expandEnd * 0.4));
    }
    if (t < _holdEnd) return 1.0;
    if (t < _holdEnd + (_shrinkEnd - _holdEnd) * 0.4) {
      return 1.0 - Curves.easeIn.transform(
        (t - _holdEnd) / ((_shrinkEnd - _holdEnd) * 0.4),
      );
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final wp = _widthProgress(t);
        final tp = _textOpacity(t);

        // 圆形 36px → 胶囊 110px
        final width = 36.0 + (110.0 - 36.0) * wp;
        final radius = 18.0 + 2.0 * wp; // 18→20

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                height: 36,
                width: width,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withAlpha(200)],
                  ),
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withAlpha(50),
                      blurRadius: 4 + wp * 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: onPrimary),
                    if (tp > 0.01) ...[
                      SizedBox(width: 6 * wp),
                      Flexible(
                        child: Opacity(
                          opacity: tp.clamp(0.0, 1.0),
                          child: Text(
                            'AI 推荐',
                            style: TextStyle(
                              color: onPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
