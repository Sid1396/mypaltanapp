import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../config/tournament_options.dart';
import '../../utils/helpers/image_prep.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../controllers/create_tournament_controller.dart';
import 'form_widgets.dart';
import 'tournament_form_widgets.dart';

String fileSizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

/// Dashed-looking "+ Add something" row.
class AddRowButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;
  const AddRowButton({super.key, required this.icon, required this.label, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: SizeConfig.h(15)),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(color: AppColors.primary.withAlpha(60), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(width: SizeConfig.r(18), height: SizeConfig.r(18), child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            else
              Icon(icon, size: SizeConfig.r(19), color: AppColors.primary),
            SizedBox(width: SizeConfig.w(8)),
            Text(busy ? 'Uploading…' : label, style: tfStyle(14, weight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _ItemTile({required this.leading, required this.title, required this.subtitle, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(SizeConfig.r(10)),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(color: Colors.white.withAlpha(12)),
        ),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(SizeConfig.r(10)), child: SizedBox(width: SizeConfig.r(44), height: SizeConfig.r(44), child: leading)),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w700)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(12, color: Colors.white.withAlpha(130))),
                ],
              ),
            ),
            IconButton(onPressed: onRemove, icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withAlpha(140), size: SizeConfig.r(20))),
          ],
        ),
      ),
    );
  }
}

class DocumentTile extends StatelessWidget {
  final DocumentDraft doc;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const DocumentTile({super.key, required this.doc, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isPdf = doc.file.mimeType == 'application/pdf';
    return _ItemTile(
      leading: isPdf
          ? Container(color: AppColors.primary.withAlpha(30), child: Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: SizeConfig.r(22)))
          : UploadedImage(doc.file),
      title: doc.title,
      subtitle: '${Sports.labelOf(TournamentOptions.docTypes, doc.docType)} · ${isPdf ? 'PDF' : 'Image'}'
          '${doc.file.sizeBytes > 0 ? ' · ${fileSizeLabel(doc.file.sizeBytes)}' : ''}',
      onTap: onTap,
      onRemove: onRemove,
    );
  }
}

class SponsorTile extends StatelessWidget {
  final SponsorDraft sponsor;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const SponsorTile({super.key, required this.sponsor, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _ItemTile(
      leading: UploadedImage(sponsor.logo),
      title: sponsor.name,
      subtitle: [sponsor.label, if (sponsor.isTitle && !sponsor.label.toLowerCase().contains('title')) 'Title sponsor'].join(' · '),
      onTap: onTap,
      onRemove: onRemove,
    );
  }
}

// ─── Document editor ────────────────────────────────────────────

void showDocumentEditor(CreateTournamentController c, {int? index}) {
  Get.bottomSheet(_DocumentEditor(c: c, index: index), isScrollControlled: true);
}

class _DocumentEditor extends StatefulWidget {
  final CreateTournamentController c;
  final int? index;
  const _DocumentEditor({required this.c, this.index});

  @override
  State<_DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<_DocumentEditor> {
  late final _title = TextEditingController();
  String _type = 'RULES';
  UploadedFile? _file;

  @override
  void initState() {
    super.initState();
    final i = widget.index;
    if (i != null) {
      final d = widget.c.documents[i];
      _title.text = d.title;
      _type = d.docType;
      _file = d.file;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await widget.c.pickDocument();
    if (f == null || !mounted) return;
    setState(() => _file = f);
    if (_title.text.trim().isEmpty) _title.text = Sports.labelOf(TournamentOptions.docTypes, _type);
  }

  void _save() {
    final title = _title.text.trim();
    if (_file == null) return AppSnackbar.error('Document', 'Choose a file to upload.');
    if (title.isEmpty || title.length > 100) return AppSnackbar.error('Document', 'Give the document a title (up to 100 characters).');
    final d = DocumentDraft(docType: _type, title: title, file: _file!);
    widget.index == null ? widget.c.addDocument(d) : widget.c.replaceDocument(widget.index!, d);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final f = _file;
    return SheetFrame(
      title: widget.index == null ? 'Add a document' : 'Edit document',
      children: [
        const FormLabel('Type'),
        ChoiceChips(options: TournamentOptions.docTypes, selected: _type, onSelected: (v) => setState(() => _type = v)),
        gapH(16),
        const FormLabel('Title'),
        FieldTextInput(controller: _title, hint: 'e.g. Rule book 2027', maxLength: 100, textCapitalization: TextCapitalization.sentences),
        gapH(16),
        const FormLabel('File'),
        Obx(() => f == null || widget.c.docBusy.value
            ? AddRowButton(icon: Icons.upload_file_rounded, label: 'Choose PDF or image', busy: widget.c.docBusy.value, onTap: _pick)
            : _ItemTile(
                leading: f.mimeType == 'application/pdf'
                    ? Container(color: AppColors.primary.withAlpha(30), child: Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: SizeConfig.r(22)))
                    : UploadedImage(f),
                title: f.mimeType == 'application/pdf' ? 'PDF uploaded' : 'Image uploaded',
                subtitle: f.sizeBytes > 0 ? fileSizeLabel(f.sizeBytes) : 'Tap to replace',
                onTap: _pick,
                onRemove: () => setState(() => _file = null),
              )),
        gapH(20),
        Obx(() => SizedBox(
              width: double.infinity,
              child: SmallButtonLarge(label: widget.index == null ? 'Add document' : 'Save', onTap: widget.c.docBusy.value ? null : _save),
            )),
      ],
    );
  }
}

// ─── Sponsor editor ─────────────────────────────────────────────

void showSponsorEditor(CreateTournamentController c, {int? index}) {
  Get.bottomSheet(_SponsorEditor(c: c, index: index), isScrollControlled: true);
}

class _SponsorEditor extends StatefulWidget {
  final CreateTournamentController c;
  final int? index;
  const _SponsorEditor({required this.c, this.index});

  @override
  State<_SponsorEditor> createState() => _SponsorEditorState();
}

class _SponsorEditorState extends State<_SponsorEditor> {
  static const _labels = ['Title sponsor', 'Powered by', 'Associate sponsor', 'Partner'];
  final _name = TextEditingController();
  final _label = TextEditingController();
  final _link = TextEditingController();
  final _tagline = TextEditingController();
  final _logo = UploadSlot();
  final _banner = UploadSlot();
  bool _isTitle = false;
  int? _id;

  @override
  void initState() {
    super.initState();
    final i = widget.index;
    if (i != null) {
      final s = widget.c.sponsors[i];
      _id = s.id;
      _name.text = s.name;
      _label.text = s.label;
      _link.text = s.linkUrl ?? '';
      _tagline.text = s.tagline ?? '';
      _logo.file.value = s.logo;
      _banner.file.value = s.banner;
      _isTitle = s.isTitle;
    }
  }

  @override
  void dispose() {
    for (final t in [_name, _label, _link, _tagline]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(UploadSlot slot, String kind, ImageShape shape) async {
    final f = await widget.c.uploadImage(kind, shape, slot: slot);
    if (f != null) slot.file.value = f;
  }

  void _save() {
    final name = _name.text.trim(), label = _label.text.trim(), tagline = _tagline.text.trim();
    var link = _link.text.trim();
    if (link.isNotEmpty && !RegExp(r'^https?://', caseSensitive: false).hasMatch(link)) link = 'https://$link';
    String? err;
    if (name.isEmpty || name.length > 80) {
      err = 'Enter the sponsor name (up to 80 characters).';
    } else if (label.isEmpty || label.length > 40) {
      err = 'Add a label, e.g. Title sponsor.';
    } else if (_logo.busy.value || _banner.busy.value) {
      err = 'Wait for the upload to finish.';
    } else if (!_logo.isSet) {
      err = 'Add the sponsor logo.';
    } else if (link.isNotEmpty && (link.length > 255 || !RegExp(r'^https?://[^\s]+\.[^\s]+$', caseSensitive: false).hasMatch(link))) {
      err = 'Enter a valid website link.';
    } else if (tagline.length > 80) {
      err = 'Tagline must be under 80 characters.';
    }
    if (err != null) return AppSnackbar.error('Sponsor', err);
    widget.c.upsertSponsor(
      SponsorDraft(
        id: _id,
        name: name,
        label: label,
        isTitle: _isTitle,
        logo: _logo.file.value!,
        banner: _banner.file.value,
        linkUrl: link.isEmpty ? null : link,
        tagline: tagline.isEmpty ? null : tagline,
      ),
      at: widget.index,
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: widget.index == null ? 'Add a sponsor' : 'Edit sponsor',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UploadBox(
              slot: _logo,
              aspectRatio: 1,
              width: SizeConfig.w(96),
              label: 'Logo',
              onPick: () => _pick(_logo, 'SPONSOR_LOGO', ImageShape.square),
            ),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FormLabel('Sponsor name'),
                  FieldTextInput(controller: _name, hint: 'e.g. Shree Sports', maxLength: 80, textCapitalization: TextCapitalization.words),
                ],
              ),
            ),
          ],
        ),
        gapH(16),
        const FormLabel('Label', hint: 'How they appear, e.g. Title sponsor or Powered by.'),
        FieldTextInput(controller: _label, hint: 'Label', maxLength: 40, textCapitalization: TextCapitalization.words),
        gapH(8),
        Wrap(
          spacing: SizeConfig.w(6),
          runSpacing: SizeConfig.h(6),
          children: [
            for (final l in _labels)
              GestureDetector(
                onTap: () => setState(() {
                  _label.text = l;
                  if (l == 'Title sponsor') _isTitle = true;
                }),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(5)),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(12), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                  child: Text(l, style: tfStyle(12, weight: FontWeight.w600, color: Colors.white.withAlpha(200))),
                ),
              ),
          ],
        ),
        gapH(8),
        SwitchRow(
          label: 'Title sponsor',
          hint: 'Shown at the top of the tournament page. Only one per tournament.',
          value: _isTitle,
          onChanged: (v) => setState(() => _isTitle = v),
        ),
        gapH(12),
        const FormLabel('Banner', optional: true, hint: 'A wide ad shown on the tournament page.'),
        UploadBox(
          slot: _banner,
          aspectRatio: 16 / 9,
          label: 'Add banner',
          hint: '16:9',
          icon: Icons.panorama_rounded,
          onPick: () => _pick(_banner, 'SPONSOR_BANNER', ImageShape.banner),
          onRemove: () => _banner.file.value = null,
        ),
        gapH(16),
        const FormLabel('Website or Instagram link', optional: true),
        FieldTextInput(controller: _link, hint: 'https://', keyboardType: TextInputType.url, maxLength: 255),
        gapH(16),
        const FormLabel('Tagline', optional: true),
        FieldTextInput(controller: _tagline, hint: 'e.g. Gear up with the best', maxLength: 80, textCapitalization: TextCapitalization.sentences),
        gapH(20),
        SizedBox(width: double.infinity, child: SmallButtonLarge(label: widget.index == null ? 'Add sponsor' : 'Save', onTap: _save)),
      ],
    );
  }
}

/// Full-width orange button for sheets.
class SmallButtonLarge extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const SmallButtonLarge({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SizeConfig.h(52),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withAlpha(110),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14))),
        ),
        child: Text(label, style: tfStyle(15, weight: FontWeight.w700)),
      ),
    );
  }
}
