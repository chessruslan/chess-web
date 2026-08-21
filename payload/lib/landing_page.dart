// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'ui/common_top_bar.dart';

import 'localization/makechess_localization.dart';
/// Стартовая страница (лендинг).
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 1080;
    final isMobile = w < 900;

    // ---- ВЕСЬ КОНТЕНТ ЛЕНДИНГА (как был), но вынесен в отдельный виджет ----
    final Widget landingContent = Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HERO
          Flex(
            direction: isWide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 6 : 0,
                child: _HeroLeft(
                  onPlay: () => Navigator.pushNamed(context, '/play'),
                ),
              ),
              if (isWide)
                const SizedBox(width: 24)
              else
                const SizedBox(height: 24),
              Expanded(
                flex: isWide ? 5 : 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _BoardPreview(size: math.min(520, w - 48)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Фичи
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _FeatureCard(
                colorDot: Color(0xFF39D353),
                title: 'AI-тренер',
                text: 'Объясняет «почему», даёт задания и план',
              ),
              _FeatureCard(
                colorDot: Color(0xFFF1A23A),
                title: '2×2 Команды',
                text: 'Дуэт против дуэта — играйте вместе',
              ),
              _FeatureCard(
                colorDot: Color(0xFF70A5FF),
                title: 'Пазл дня',
                text: 'Одна задача в день — рост рейтинга задач',
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Курсы
          MakeChessLocalizedText(
            'Учебные курсы',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _CourseCard(title: 'Старт для новичка'),
              _CourseCard(title: 'Тактика без зубрёжки'),
              _CourseCard(title: 'Эндшпили базовые'),
              _CourseCard(title: 'Дебюты: идеи'),
            ],
          ),

          const SizedBox(height: 24),
          const MakeChessLocalizedText(
            '© TwinChess — игра, обучение и командный режим 2×2',
            style: TextStyle(color: Color(0xFF9BA3AF)),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: MediaQuery.of(context).size.width < 900
          ? ListView(
              padding: EdgeInsets.zero,
              children: [landingContent],
            )
          : SingleChildScrollView(
              child: landingContent,
            ),
    );
  }
}

/// Левая часть «героя».
class _HeroLeft extends StatelessWidget {
  const _HeroLeft({required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MakeChessLocalizedText(
          'Играйте и учитесь\nс голосовым AI-тренером',
          style: TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        const MakeChessLocalizedText(
          'Быстрые матчи, разбор «почему», пазлы и командный режим 2×2.',
          style: TextStyle(color: Color(0xFF9BA3AF), fontSize: 16),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: onPlay,
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ),
              ),
              child: const MakeChessLocalizedText(
                'Играть сейчас 10×',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2B3240)),
                foregroundColor: const Color(0xFFCDD6E1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: const Color(0xFF1F242D),
              ),
              child: const MakeChessLocalizedText(
                'Попробовать урок',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            _StatDot(text: 'Сейчас онлайн: 12 480'),
            SizedBox(width: 18),
            _StatDot(text: 'Партии сегодня: 1,2 млн'),
          ],
        ),
      ],
    );
  }
}

class _StatDot extends StatelessWidget {
  const _StatDot({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF2B3240),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        MakeChessLocalizedText(
          text,
          style: const TextStyle(color: Color(0xFF9BA3AF)),
        ),
      ],
    );
  }
}

/// Превью доски (визуал без логики)
class _BoardPreview extends StatelessWidget {
  const _BoardPreview({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final cell = (size / 8).floorToDouble();
    return Container(
      width: cell * 8,
      height: cell * 8,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F141A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.45),
            blurRadius: 28,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1,
              ),
              itemCount: 64,
              itemBuilder: (_, i) {
                final r = i ~/ 8, c = i % 8;
                final light = (r + c) % 2 == 0;
                return Container(
                  color:
                      light ? const Color(0xFF2B3240) : const Color(0xFF1F242D),
                );
              },
            ),
            Positioned(
              left: cell * 5,
              top: cell * 4,
              child: Container(
                width: cell - 2,
                height: cell - 2,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF18E0FF), width: 3),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.colorDot,
    required this.title,
    required this.text,
  });

  final Color colorDot;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF192028),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2B3240)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: colorDot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MakeChessLocalizedText(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                MakeChessLocalizedText(
                  text,
                  style: const TextStyle(color: Color(0xFF9BA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2B3240)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1F242D),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          MakeChessLocalizedText(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const MakeChessLocalizedText(
            'Попробовать →',
            style: TextStyle(color: Color(0xFF70A5FF)),
          ),
        ],
      ),
    );
  }
}
