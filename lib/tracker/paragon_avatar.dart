import 'package:flutter/material.dart';
import 'package:parallel_stats/tracker/paragon.dart';
import 'package:http/http.dart' as http;

class ParagonAvatar extends StatelessWidget {
  final Paragon paragon;

  const ParagonAvatar({
    super.key,
    required this.paragon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: paragon.parallel.backgroundGradient,
        ),
        child: Tooltip(
          message: paragon.name,
          child: CircleAvatar(
            radius: 36,
            backgroundColor: Colors.transparent,
            child: paragon.image.startsWith("http")
                ? FutureBuilder(
                    future: http.get(Uri.parse(paragon.image)),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasError) {
                          return const Icon(Icons.error);
                        }
                        return CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.transparent,
                          backgroundImage:
                              MemoryImage(snapshot.data!.bodyBytes),
                        );
                      }
                      return const CircularProgressIndicator();
                    },
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.transparent],
                          stops: [0.6, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(paragon.image),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
