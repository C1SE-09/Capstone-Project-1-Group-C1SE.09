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
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (form._late) ...[
              Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: k.warnTint,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          'Loại đơn mới — báo trước để giáo viên nắm lịch đến lớp của bé',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: k.warnDeep)))),
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
            if (!form._late) ...[
              ParentRequestChild(
                  child: form.widget.child,
                  className: form.widget.className,
                  teacherName: form.widget.teacherName),
              const SizedBox(height: 12),
            ],
            _label(context, form._late ? 'Ngày đi trễ' : 'Từ ngày'),
            _date(context, requestDayLabel(form._from),
                disabled ? null : () => form._pickDate(),
                emphasized: !form._late),
            if (!form._late) ...[
              const SizedBox(height: 12),
              _label(context, 'Đến ngày'),
              _date(context, requestDayLabel(form._to),
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
                  disabled ? null : form._pickTime,
                  strong: true),
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
                          brandTone: true,
                          onPressed:
                              disabled ? null : () => form._changeEta(time)),
                      const SizedBox(width: 6),
                    ],
                  ])),
            ],
            const SizedBox(height: 12),
            _label(context, form._late ? 'Lý do đi trễ' : 'Lý do xin nghỉ'),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: _inputColor(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: k.line)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                          controller: form._reason,
                          enabled: !disabled,
                          minLines: 2,
                          maxLines: 5,
                          maxLength: 1000,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          style: TextStyle(fontSize: 14, color: k.ink),
                          decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              counterText: '',
                              hintText: form._late
                                  ? 'Nhập lý do bé đến lớp muộn'
                                  : 'Nhập lý do xin nghỉ của bé',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none),
                          validator: (value) {
                            final length =
                                (value ?? '').trim().characters.length;
                            if (length < 3) {
                              return 'Lý do cần ít nhất 3 ký tự sau khi bỏ khoảng trắng.';
                            }
                            if (length > 1000) {
                              return 'Lý do tối đa 1000 ký tự.';
                            }
                            return null;
                          }),
                      if (!form._late)
                        Text(
                            '${form._reason.text.trim().characters.length}/1000',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 10.5,
                                color:
                                    form._reason.text.trim().characters.length >
                                            1000
                                        ? k.bad
                                        : k.inkSoft)),
                    ])),
            if (!form._late) ...[
              const SizedBox(height: 12),
              Text('Lý do tối thiểu 3 ký tự – hệ thống kiểm tra khi gửi.',
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
                      side: BorderSide(color: k.line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: Row(children: [
                    Expanded(
                        flex: 5,
                        child: Text(
                            form._pickingImage
                                ? 'Đang mở ảnh…'
                                : '+ Thêm ảnh giấy khám / đơn thuốc',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Flexible(
                        flex: 2,
                        child: Text('Không bắt buộc',
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 11, color: k.inkSoft))),
                  ])),
            ],
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
            if (form._imageBytes != null)
              Text('Ảnh y tế riêng tư · JPEG, PNG, WebP · Tối đa 5 MiB',
                  style: TextStyle(fontSize: 11, color: k.inkSoft)),
            if (form._error != null) ...[
              const SizedBox(height: 12),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: k.badTint,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 18, color: k.bad),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Semantics(
                                liveRegion: true,
                                child: Text(form._error!,
                                    style: TextStyle(
                                        fontSize: 12.5, color: k.ink)))),
                      ])),
              if (form._overlap)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: disabled
                            ? null
                            : () =>
                                form._discard(ParentRequestDestination.history),
                        child: const Text('Xem lịch sử đơn'))),
            ],
            const SizedBox(height: 12),
            ParentRequestButton(
                label: form._late ? 'GỬI THÔNG BÁO' : 'GỬI ĐƠN',
                onPressed: disabled ? null : form._submit,
                busy: form._busy),
            const SizedBox(height: 8),
            Text(
                form._late
                    ? 'Giáo viên sẽ thấy ghi chú đi trễ khi điểm danh buổi sáng.'
                    : 'Đơn sẽ được gửi tới giáo viên chủ nhiệm để duyệt.',
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
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, 62),
                padding: const EdgeInsets.all(12),
                side: BorderSide(
                    color: selected ? context.k.brand : context.k.line,
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

  Color _inputColor(BuildContext context) => context.k.surface;

  Widget _date(BuildContext context, String value, VoidCallback? onTap,
          {bool emphasized = false}) =>
      _control(context, value, 'Chọn ngày', onTap,
          borderColor: emphasized ? context.k.brand : context.k.line);

  Widget _control(BuildContext context, String value, String action,
          VoidCallback? onTap, {bool strong = false, Color? borderColor}) =>
      OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
              backgroundColor: _inputColor(context),
              foregroundColor: context.k.ink,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              side: BorderSide(color: borderColor ?? context.k.line),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: Row(children: [
            Expanded(
                flex: 4,
                child: Text(value,
                    style: TextStyle(
                        fontSize: strong ? 20 : 14,
                        fontWeight:
                            strong ? FontWeight.w700 : FontWeight.w600))),
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
