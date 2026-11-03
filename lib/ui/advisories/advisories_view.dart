import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdvisoriesView extends StatefulWidget {
  const AdvisoriesView({super.key});

  @override
  State<AdvisoriesView> createState() => _AdvisoriesViewState();
}

class _AdvisoriesViewState extends State<AdvisoriesView> {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          leading: Row(
            children: [
              IconButton(
                onPressed: () {
                  context.go('/');
                },
                icon: const Icon(Icons.arrow_back),
              ),
            ],
          ),
          pinned: true,
          title: const Text('Advisories'),
        ),
      ],
    );
  }
}
