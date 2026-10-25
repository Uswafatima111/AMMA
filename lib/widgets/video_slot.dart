import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/patient_palette.dart';

/// A 16:9 video card. With no [videoUrl] it shows a "coming soon" placeholder.
/// Once you have a video, pass its link (e.g. an unlisted YouTube link) and
/// tapping opens it. Later this can be swapped for in-app playback.
class VideoSlot extends StatelessWidget {
  final String title;
  final String? videoUrl;

  const VideoSlot({super.key, required this.title, this.videoUrl});

  Future<void> _play(BuildContext context) async {
    if (videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This video is coming soon')),
      );
      return;
    }
    try {
      await launchUrl(Uri.parse(videoUrl!),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the video')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _play(context),
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PatientPalette.navy, PatientPalette.navyDeep],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: PatientPalette.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 44, color: Colors.white),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Text(
                  title,
                  style: GoogleFonts.lora(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (videoUrl == null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Video coming soon',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}