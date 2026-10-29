part of 'parent_requests_form_screen.dart';

class _ParentRequestFormFields extends StatelessWidget {
  const _ParentRequestFormFields(this.form);
  final _ParentRequestFormScreenState form;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final disabled = form._busy || form._pickingImage;
    return Form(
        key: form._formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (form._late) ...[
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: k.warnTint,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('Báo trước để giáo viên nắm lịch đến lớp của bé',
                      style: TextStyle(fontSize: 11, color: k.warnDeep))),
              const SizedBox(height: 12),
            ],
            _label(context, 'Loại đơn'),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final type in LeaveRequestType.values) ...[
                if (type == LeaveRequestType.lateArrival)
                  const SizedBox(width: 8),
                Expanded(child: _type(context, type, disabled)),
              ],
            ]),
            const SizedBox(height: 12),
            ParentRequestChild(
                child: form.widget.child,
                className: form.widget.className,
                teacherName: form.widget.teacherName),
            const SizedBox(height: 12),
            _label(context, form._late ? 'Ngày đi trễ' : 'Từ ngày'),
            _date(context, requestDate(form._from),
                disabled ? null : () => form._pickDate()),
            if (!form._late) ...[
              const SizedBox(height: 12),
              _label(context, 'Đến ngày'),
              _date(context, requestDate(form._to),
                  disabled ? null : () => form._pickDate(end: true)),
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: k.brandTint,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('Tổng thời gian nghỉ: ${form._days} ngày',
                          style: TextStyle(
                              color: k.brand,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)))),
            ] else ...[
              const SizedBox(height: 12),
              _label(context, 'Giờ đến dự kiến'),
              _control(
                  context,
                  '${form._eta.hour.toString().padLeft(2, '0')}:${form._eta.minute.toString().padLeft(2, '0')}',
                  'Chọn giờ',
                  disabled ? null : form._pickTime),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final time in const [
                      TimeOfDay(hour: 7, minute: 45),
                      TimeOfDay(hour: 8, minute: 0),
                      TimeOfDay(hour: 8, minute: 30),
                      TimeOfDay(hour: 9, minute: 0)
                    ]) ...[
                      ParentRequestPill(
                          label:
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          selected: form._eta == time,
                          onPressed:
                              disabled ? null : () => form._changeEta(time)),
                      const SizedBox(width: 6),
                    ],
                  ])),
            ],
            const SizedBox(height: 12),
            _label(context, form._late ? 'Lý do đi trễ' : 'Lý do xin nghỉ'),
            TextFormField(
                controller: form._reason,
                enabled: !disabled,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                style: TextStyle(fontSize: 13, color: k.ink),
                decoration: InputDecoration(
                    hintText: form._late
                        ? 'Nhập lý do bé đến lớp muộn'
                        : 'Nhập lý do xin nghỉ của bé',
                    fillColor: _inputColor(context),
                    border: _border(context),
                    enabledBorder: _border(context),
                    focusedBorder: _border(context, focused: true)),
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    Text('${form._reason.text.trim().characters.length}/1000',
                        style: TextStyle(
                            fontSize: 11,
                            color: form._reason.text.trim().characters.length >
                                    1000
                                ? k.bad
                                : k.inkSoft)),
                validator: (value) {
                  final length = (value ?? '').trim().characters.length;
                  if (length < 3) {
                    return 'Lý do cần ít nhất 3 ký tự sau khi bỏ khoảng trắng.';
                  }
                  if (length > 1000) return 'Lý do tối đa 1000 ký tự.';
                  return null;
                }),
            const SizedBox(height: 4),
            Text('Lý do tối thiểu 3 ký tự — hệ thống kiểm tra khi gửi.',
                style: TextStyle(color: k.inkSoft, fontSize: 11)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: disabled ? null : form._pickImage,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    backgroundColor: k.surface,
                    foregroundColor: k.brand,
                    side: BorderSide(color: k.lineStrong),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                          form._pickingImage
                              ? 'Đang mở ảnh…'
                              : '+ Thêm ảnh giấy khám / đơn thuốc',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('Không bắt buộc',
                          style: TextStyle(fontSize: 11, color: k.inkSoft)),
                    ])),
            if (form._imageBytes != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(form._imageBytes!,
                      height: 140,
                      fit: BoxFit.contain,
                      semanticLabel: 'Ảnh y tế đã chọn',
                      errorBuilder: (_, __, ___) => const Text(
                          'Không thể xem trước ảnh; hệ thống sẽ kiểm tra khi gửi.'))),
              Row(children: [
                Expanded(
                    child: Text(form._imageName!,
                        style: const TextStyle(fontSize: 11))),
                IconButton(
                    tooltip: 'Xóa ảnh đính kèm',
                    onPressed: disabled ? null : form._removeImage,
                    icon: const Icon(Icons.close, size: 20))
              ]),
            ],
            Text('Ảnh y tế riêng tư · JPEG, PNG, WebP · Tối đa 5 MiB',
                style: TextStyle(fontSize: 11, color: k.inkSoft)),
            if (form._error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                  liveRegion: true,
                  child: Text(form._error!, style: TextStyle(color: k.bad))),
              if (form._overlap)
                TextButton(
                    onPressed: disabled
                        ? null
                        : () => form._discard(ParentRequestDestination.history),
                    child: const Text('Xem lịch sử đơn')),
            ],
            const SizedBox(height: 12),
            ParentRequestButton(
                label: 'GỬI ĐƠN',
                onPressed: disabled ? null : form._submit,
                busy: form._busy),
            const SizedBox(height: 8),
            Text('Đơn sẽ được gửi tới giáo viên chủ nhiệm để duyệt.',
                style: TextStyle(fontSize: 11, color: k.inkSoft)),
          ]),
        ));
  }

  Widget _label(BuildContext context, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: context.k.inkSoft,
              fontWeight: FontWeight.w600)));

  Widget _type(BuildContext context, LeaveRequestType type, bool disabled) {
    final selected = form._type == type;
    return Semantics(
        selected: selected,
        child: OutlinedButton(
            onPressed: disabled ? null : () => form._changeType(type),
            style: OutlinedButton.styleFrom(
                backgroundColor:
                    selected ? context.k.brandTint : context.k.surface,
                foregroundColor: selected ? context.k.brand : context.k.ink,
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.all(12),
                side: BorderSide(
                    color: selected ? context.k.brand : context.k.lineStrong,
                    width: selected ? 1.5 : 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(requestTypeLabel(type),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              Text(
                  type == LeaveRequestType.absence
                      ? '1 ngày hoặc nhiều ngày'
                      : 'Đến lớp muộn trong ngày',
                  style: TextStyle(fontSize: 11, color: context.k.inkSoft)),
            ])));
  }

  Color _inputColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFFAF9F6)
          : context.k.surface;

  OutlineInputBorder _border(BuildContext context, {bool focused = false}) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: focused ? context.k.brand : context.k.lineStrong));

  Widget _date(BuildContext context, String value, VoidCallback? onTap) =>
      _control(context, value, 'Chọn ngày', onTap);

  Widget _control(BuildContext context, String value, String action,
          VoidCallback? onTap) =>
      OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
              backgroundColor: _inputColor(context),
              foregroundColor: context.k.ink,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              side: BorderSide(color: context.k.lineStrong),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: Row(children: [
            Expanded(
                flex: 3,
                child: Text(value, style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            Flexible(
                flex: 2,
                child: SizedBox(
                    width: double.infinity,
                    child: Text(action,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            color: context.k.brand,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))))
          ]));
}
