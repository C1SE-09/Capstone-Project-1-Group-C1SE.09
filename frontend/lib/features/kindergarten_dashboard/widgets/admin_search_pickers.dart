import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_admin_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

Future<String?> showChildSearchPicker(
  BuildContext context,
  List<AdminChildDto> students, {
  String? currentSelectedId,
  bool allowNone = true,
  String title = 'Chọn học sinh liên kết',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      String query = '';
      return StatefulBuilder(
        builder: (context, setModalState) {
          final q = query.toLowerCase().trim();
          final filtered = students.where((c) {
            if (q.isEmpty) return true;
            final matchName = c.fullName.toLowerCase().contains(q);
            final matchNick = c.nickname.toLowerCase().contains(q);
            final matchClass = c.className.toLowerCase().contains(q);
            return matchName || matchNick || matchClass;
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Text(
                              'Tìm theo họ tên, biệt danh hoặc lớp (${filtered.length}/${students.length})',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    autofocus: false,
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên bé, biệt danh (vd: Bắp, Miu) hoặc lớp...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setModalState(() => query = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      if (allowNone)
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.black12,
                            child: Icon(Icons.person_off_outlined, size: 20),
                          ),
                          title: const Text('Chưa liên kết / Không chọn bé'),
                          trailing: currentSelectedId == null || currentSelectedId.isEmpty
                              ? const Icon(Icons.check_circle, color: KColors.brand)
                              : null,
                          onTap: () => Navigator.pop(ctx, '__none__'),
                        ),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Không tìm thấy học sinh phù hợp với "$query"',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        ...filtered.map((c) {
                          final isSelected = c.id == currentSelectedId;
                          final hasNick = c.nickname.isNotEmpty;
                          final hasClass = c.className.isNotEmpty;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              tileColor: isSelected
                                  ? KColors.brand.withAlpha(25)
                                  : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected ? KColors.brand : Theme.of(context).dividerColor,
                                ),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: KColors.brand.withAlpha(30),
                                child: const Icon(Icons.child_care_rounded, color: KColors.brand),
                              ),
                              title: Text(
                                c.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              subtitle: Text(
                                [
                                  if (hasNick) 'Biệt danh: ${c.nickname}',
                                  if (hasClass) 'Lớp: ${c.className}',
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: KColors.brand)
                                  : const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () => Navigator.pop(ctx, c.id),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<List<String>?> showParentSearchMultiPicker(
  BuildContext context,
  List<AdminParentDto> parents, {
  List<String> currentSelectedIds = const [],
  String title = 'Chọn phụ huynh liên kết (N - N)',
}) {
  final selectedIds = Set<String>.from(currentSelectedIds);
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      String query = '';
      return StatefulBuilder(
        builder: (context, setModalState) {
          final q = query.toLowerCase().trim();
          final filtered = parents.where((p) {
            if (q.isEmpty) return true;
            final matchName = p.fullName.toLowerCase().contains(q);
            final matchPhone = p.phone.toLowerCase().contains(q);
            final matchEmail = p.email.toLowerCase().contains(q);
            final matchUser = (p.username ?? '').toLowerCase().contains(q);
            return matchName || matchPhone || matchEmail || matchUser;
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Text(
                              'Đã chọn ${selectedIds.length} phụ huynh · Tìm theo tên, SĐT (${filtered.length}/${parents.length})',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, selectedIds.toList()),
                        child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    autofocus: false,
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên phụ huynh hoặc số điện thoại...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setModalState(() => query = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Không tìm thấy phụ huynh phù hợp với "$query"',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        ...filtered.map((p) {
                          final isSelected = selectedIds.contains(p.id);
                          final role = p.relationship != null && p.relationship!.isNotEmpty
                              ? ' (${p.relationship})'
                              : '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              tileColor: isSelected
                                  ? KColors.brand.withAlpha(25)
                                  : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected ? KColors.brand : Theme.of(context).dividerColor,
                                ),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? KColors.brand
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.person,
                                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              title: Text(
                                '${p.fullName}$role',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              subtitle: Text(
                                [
                                  if (p.phone.isNotEmpty) 'SĐT: ${p.phone}',
                                  if (p.childrenSummary.isNotEmpty) 'Con: ${p.childrenSummary}',
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                activeColor: KColors.brand,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      selectedIds.add(p.id);
                                    } else {
                                      selectedIds.remove(p.id);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    selectedIds.remove(p.id);
                                  } else {
                                    selectedIds.add(p.id);
                                  }
                                });
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
