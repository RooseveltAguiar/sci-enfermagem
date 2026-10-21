import 'package:flutter/material.dart';

class TimelineStepData {
  final String titulo;
  final String? dataHora;
  final String? responsavel;
  final bool concluido;
  final bool atual;

  TimelineStepData({
    required this.titulo,
    this.dataHora,
    this.responsavel,
    this.concluido = false,
    this.atual = false,
  });
}

class TimelineAvaliacao extends StatelessWidget {
  final List<TimelineStepData> steps;

  const TimelineAvaliacao({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Linha do Tempo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...List.generate(steps.length, (index) {
          final step = steps[index];
          final isLast = index == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step.concluido
                          ? Colors.teal
                          : (step.atual
                              ? Colors.amber.shade700
                              : Colors.grey.shade300),
                    ),
                    child: Icon(
                      step.concluido
                          ? Icons.check
                          : (step.atual ? Icons.access_time : Icons.circle),
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 36,
                      color: step.concluido
                          ? Colors.teal
                          : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.titulo,
                        style: TextStyle(
                          fontWeight: step.concluido || step.atual
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: step.concluido || step.atual
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (step.dataHora != null || step.responsavel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (step.responsavel != null) step.responsavel,
                            if (step.dataHora != null) step.dataHora,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
