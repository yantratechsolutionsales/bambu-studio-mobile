class BomItem {
  const BomItem({
    required this.id,
    required this.name,
    required this.spec,
    required this.quantity,
    required this.category,
  });

  final String id;
  final String name;
  final String spec;
  final int quantity;
  final String category;
}

class AssemblyStep {
  const AssemblyStep({
    required this.stepNumber,
    required this.title,
    required this.instructions,
    required this.partsUsed,
  });

  final int stepNumber;
  final String title;
  final String instructions;
  final List<String> partsUsed;
}

class ProjectMetadata {
  const ProjectMetadata({
    required this.title,
    required this.author,
    required this.license,
    required this.description,
    required this.printProfileNotes,
    required this.tags,
    required this.bomItems,
    required this.assemblySteps,
    required this.lastModified,
  });

  final String title;
  final String author;
  final String license;
  final String description;
  final String printProfileNotes;
  final List<String> tags;
  final List<BomItem> bomItems;
  final List<AssemblyStep> assemblySteps;
  final DateTime lastModified;

  ProjectMetadata copyWith({
    String? title,
    String? author,
    String? license,
    String? description,
    String? printProfileNotes,
    List<String>? tags,
    List<BomItem>? bomItems,
    List<AssemblyStep>? assemblySteps,
    DateTime? lastModified,
  }) {
    return ProjectMetadata(
      title: title ?? this.title,
      author: author ?? this.author,
      license: license ?? this.license,
      description: description ?? this.description,
      printProfileNotes: printProfileNotes ?? this.printProfileNotes,
      tags: tags ?? this.tags,
      bomItems: bomItems ?? this.bomItems,
      assemblySteps: assemblySteps ?? this.assemblySteps,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  String toMarkdownGuide() {
    final buf = StringBuffer()
      ..writeln('# $title')
      ..writeln('**Designer:** $author | **License:** $license')
      ..writeln()
      ..writeln('## Overview')
      ..writeln(description)
      ..writeln()
      ..writeln('## Print Profile Notes')
      ..writeln(printProfileNotes)
      ..writeln()
      ..writeln('## Bill of Materials (BOM)');
    for (final item in bomItems) {
      buf.writeln('- ${item.quantity}x ${item.name} (${item.spec}) — ${item.category}');
    }
    buf.writeln('\n## Assembly Guide');
    for (final s in assemblySteps) {
      buf.writeln('### Step ${s.stepNumber}: ${s.title}');
      buf.writeln(s.instructions);
      if (s.partsUsed.isNotEmpty) {
        buf.writeln('*Parts:* ${s.partsUsed.join(", ")}');
      }
      buf.writeln();
    }
    return buf.toString();
  }
}

class RecentProjectItem {
  const RecentProjectItem({
    required this.id,
    required this.name,
    required this.printerModel,
    required this.plateCount,
    required this.objectCount,
    required this.estimatedTime,
    required this.filamentGrams,
    required this.openedAgo,
    required this.presetAsset,
  });

  final String id;
  final String name;
  final String printerModel;
  final int plateCount;
  final int objectCount;
  final String estimatedTime;
  final double filamentGrams;
  final String openedAgo;
  final String presetAsset;
}

class MakerWorldModel {
  const MakerWorldModel({
    required this.id,
    required this.title,
    required this.creator,
    required this.downloads,
    required this.likes,
    required this.printTime,
    required this.filamentType,
    required this.category,
    required this.primitiveType,
  });

  final String id;
  final String title;
  final String creator;
  final String downloads;
  final int likes;
  final String printTime;
  final String filamentType;
  final String category;
  final String primitiveType;
}
