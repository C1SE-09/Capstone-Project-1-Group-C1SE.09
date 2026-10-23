/**
 * lib/excel-helper.ts
 * ===================
 * Tiện ích xuất / nhập dữ liệu Excel (.xlsx) & CSV dùng thư viện xlsx (SheetJS).
 * Hỗ trợ:
 * - Xuất 1 sheet hoặc nhiều sheet (chia theo lớp).
 * - Định dạng và phân tích ngày tháng chuẩn DD/MM/YYYY.
 * - Ánh xạ cột thông minh theo tên tiêu đề (Smart Header Mapping).
 */

import * as XLSX from "xlsx";

/**
 * Định dạng các ô dữ liệu (đặc biệt là Số điện thoại hoặc chuỗi ký tự)
 * thành kiểu Text chuẩn của Excel (format code '@' / numFmtId 49).
 * Điều này đảm bảo khi người dùng mở trong Excel và bấm vào sửa (F2 / click formula bar),
 * Excel sẽ KHÔNG tự động chuyển về dạng số và KHÔNG làm mất số 0 ở đầu.
 */
function applyTextFormatToSheet(ws: XLSX.WorkSheet) {
  if (!ws["!ref"]) return;
  const range = XLSX.utils.decode_range(ws["!ref"]);
  for (let R = range.s.r; R <= range.e.r; ++R) {
    for (let C = range.s.c; C <= range.e.c; ++C) {
      const cellAddress = XLSX.utils.encode_cell({ r: R, c: C });
      const cell = ws[cellAddress];
      if (!cell) continue;

      if (R === 0) {
        cell.t = "s";
        continue;
      }

      const valStr = String(cell.v ?? "").trim();
      const isPhoneOrZeroPrefixed = /^0\d+$/.test(valStr);

      if (isPhoneOrZeroPrefixed || cell.t === "s") {
        cell.t = "s";
        cell.z = "@"; // Format code '@' trong Excel = Text (numFmtId 49)
        cell.v = valStr;
      }
    }
  }
}

/**
 * Xuất dữ liệu ra file Excel (.xlsx) 1 sheet và kích hoạt tải về trên trình duyệt.
 */
export function exportToExcel(
  filename: string,
  sheetName: string,
  headers: string[],
  rows: (string | number)[][],
) {
  const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);
  applyTextFormatToSheet(ws);

  // Tự động căn chỉnh độ rộng các cột (tối thiểu 12 ký tự)
  const colWidths = headers.map((h, i) => {
    let maxLen = h.length;
    for (const r of rows) {
      const val = String(r[i] ?? "");
      if (val.length > maxLen) maxLen = val.length;
    }
    return { wch: Math.min(Math.max(maxLen + 3, 12), 40) };
  });
  ws["!cols"] = colWidths;

  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheetName.slice(0, 31));
  XLSX.writeFile(wb, filename);
}

export interface ExcelSheetData {
  sheetName: string;
  headers: string[];
  rows: (string | number)[][];
}

/**
 * Xuất dữ liệu ra file Excel (.xlsx) với nhiều sheet (mỗi lớp 1 sheet).
 * Tự động chuẩn hóa tên sheet theo chuẩn Excel (tối đa 31 ký tự, không chứa ký tự cấm, không trùng tên).
 */
export function exportMultiSheetToExcel(
  filename: string,
  sheets: ExcelSheetData[],
) {
  if (!sheets || sheets.length === 0) return;

  const wb = XLSX.utils.book_new();
  const usedSheetNames = new Set<string>();

  for (const sheet of sheets) {
    const ws = XLSX.utils.aoa_to_sheet([sheet.headers, ...sheet.rows]);
    applyTextFormatToSheet(ws);

    // Tự động căn chỉnh độ rộng các cột
    const colWidths = sheet.headers.map((h, i) => {
      let maxLen = h.length;
      for (const r of sheet.rows) {
        const val = String(r[i] ?? "");
        if (val.length > maxLen) maxLen = val.length;
      }
      return { wch: Math.min(Math.max(maxLen + 3, 12), 40) };
    });
    ws["!cols"] = colWidths;

    // Excel giới hạn tên sheet 31 ký tự, không chứa các ký tự \ / ? * [ ] :
    let cleanName = sheet.sheetName
      .replace(/[\\/?*\[\]:]/g, "-")
      .trim()
      .slice(0, 31) || "Sheet";

    let finalName = cleanName;
    let counter = 2;
    while (usedSheetNames.has(finalName.toLowerCase())) {
      const suffix = ` (${counter})`;
      finalName = cleanName.slice(0, Math.max(1, 31 - suffix.length)) + suffix;
      counter++;
    }
    usedSheetNames.add(finalName.toLowerCase());

    XLSX.utils.book_append_sheet(wb, ws, finalName);
  }

  XLSX.writeFile(wb, filename);
}

/**
 * Tải file mẫu Excel (.xlsx).
 */
export function downloadExcelTemplate(
  filename: string,
  sheetName: string,
  headers: string[],
  sampleRow: string[],
) {
  const ws = XLSX.utils.aoa_to_sheet([headers, sampleRow]);
  applyTextFormatToSheet(ws);
  ws["!cols"] = headers.map((h) => ({ wch: Math.max(h.length + 5, 14) }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheetName.slice(0, 31));
  XLSX.writeFile(wb, filename);
}

/**
 * Chuyển đổi ngày ISO (YYYY-MM-DD) hoặc ngày bất kỳ sang định dạng hiển thị DD/MM/YYYY cho Excel
 */
export function formatDateToDmy(dateStr: string | null | undefined): string {
  if (!dateStr) return "";
  const clean = dateStr.split("T")[0].trim();
  const parts = clean.split("-");
  if (parts.length === 3) {
    const [y, m, d] = parts;
    return `${d.padStart(2, "0")}/${m.padStart(2, "0")}/${y}`;
  }
  return clean;
}

/**
 * Chuyển đổi chuỗi ngày từ file Excel (DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD hoặc số serial Excel)
 * sang định dạng chuẩn ISO YYYY-MM-DD để gửi lên backend API.
 */
export function parseDateToIso(val: any): string | null {
  if (val === undefined || val === null) return null;
  const s = String(val).trim();
  if (!s) return null;

  // 1. Số serial của Excel (ví dụ 44331)
  if (/^\d{5}$/.test(s)) {
    const num = parseInt(s, 10);
    const date = new Date(Math.round((num - 25569) * 86400 * 1000));
    if (!isNaN(date.getTime())) {
      return date.toISOString().split("T")[0];
    }
  }

  // 2. Định dạng DD/MM/YYYY hoặc DD-MM-YYYY hoặc D/M/YYYY
  const dmyMatch = s.match(/^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$/);
  if (dmyMatch) {
    const d = parseInt(dmyMatch[1], 10);
    const m = parseInt(dmyMatch[2], 10);
    const y = parseInt(dmyMatch[3], 10);
    if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      return `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
    }
  }

  // 3. Định dạng ISO YYYY-MM-DD
  const ymdMatch = s.match(/^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/);
  if (ymdMatch) {
    const y = parseInt(ymdMatch[1], 10);
    const m = parseInt(ymdMatch[2], 10);
    const d = parseInt(ymdMatch[3], 10);
    if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      return `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
    }
  }

  return null;
}

/**
 * Chuẩn hóa chuỗi tiêu đề để so khớp (chữ thường, bỏ dấu tiếng Việt, cắt khoảng trắng thừa)
 */
export function normalizeHeader(str: string): string {
  return String(str ?? "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "d")
    .replace(/[^a-z0-9]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Danh mục từ khóa cho từng trường dữ liệu.
 * Các từ khóa mang tính đặc thù cao (ví dụ: "ten lop", "ten dang nhap", "ten hoat dong")
 * được ưu tiên kiểm tra trước các từ khóa ngắn như "ten".
 */
export const FIELD_KEYWORD_RULES: { key: string; keywords: string[] }[] = [
  // Lớp
  { key: "className", keywords: ["ten lop", "lop hoc", "lop phu trach", "phan cong lop", "class name", "classname", "lop", "class"] },
  // Hoạt động / Môn học
  { key: "activityName", keywords: ["ten hoat dong", "hoat dong", "mon hoc", "tiet hoc", "activity name", "activity"] },
  // Địa điểm / Phòng
  { key: "roomName", keywords: ["dia diem phong hoc", "dia diem", "phong hoc", "phong", "location", "room name", "room"] },
  // Khung giờ
  { key: "timeStr", keywords: ["khung gio", "thoi gian", "gio hoc", "time range", "time", "gio"] },
  // Thứ trong tuần
  { key: "dayStr", keywords: ["thu trong tuan", "ngay trong tuan", "thu", "day of week", "weekday", "day"] },
  // Nội dung chi tiết
  { key: "content", keywords: ["noi dung chi tiet", "noi dung", "mo ta", "chi tiet", "content", "description"] },
  // Tài khoản / Tên đăng nhập
  { key: "username", keywords: ["ten dang nhap", "tai khoan", "username", "user"] },
  // Mật khẩu
  { key: "password", keywords: ["mat khau", "password", "pass", "pwd"] },
  // Số điện thoại
  { key: "phone", keywords: ["so dien thoai", "dien thoai", "sdt", "phone number", "phone", "tel", "mobile"] },
  // Email
  { key: "email", keywords: ["thu dien tu", "email", "e mail", "mail"] },
  // Mối quan hệ
  { key: "relationship", keywords: ["moi quan he", "quan he voi tre", "quan he", "vai tro", "relationship", "relation"] },
  // Ngày sinh
  { key: "dob", keywords: ["ngay sinh", "ngay thang nam sinh", "nam sinh", "sinh nhat", "dob", "birth", "birthday", "date of birth"] },
  // Giới tính
  { key: "gender", keywords: ["gioi tinh", "gender", "sex"] },
  // Biệt danh
  { key: "nickname", keywords: ["biet danh", "ten o nha", "nickname", "nick name", "alias"] },
  // Ghi chú / Dị ứng
  { key: "note", keywords: ["ghi chu di ung", "di ung", "benh ly", "ghi chu", "note", "notes", "medical"] },
  // Họ và tên (xét sau để không nhầm với tên lớp, tên đăng nhập, tên hoạt động)
  { key: "fullName", keywords: ["ho va ten", "ho ten", "ten hoc sinh", "ten giao vien", "ten phu huynh", "full name", "fullname", "ho", "ten", "name"] },
];

/**
 * Nhận diện khóa dữ liệu (fieldKey) từ chuỗi tiêu đề cột
 */
export function detectFieldKey(headerText: string): string | null {
  const norm = normalizeHeader(headerText);
  if (!norm) return null;

  for (const rule of FIELD_KEYWORD_RULES) {
    for (const kw of rule.keywords) {
      if (norm === kw || norm.startsWith(kw) || norm.includes(kw)) {
        return rule.key;
      }
    }
  }
  return null;
}

export interface DetectedSheetInfo {
  name: string;
  count: number;
}

export interface ParseExcelResult {
  rows: string[][];
  sheets: DetectedSheetInfo[];
}

/**
 * Đọc file Excel (.xlsx, .xls) hoặc file CSV tải lên và trả về danh sách các dòng dữ liệu cùng thống kê theo sheet.
 * Tự động đọc và ghép toàn bộ các Sheet nếu file có nhiều sheet (ví dụ mỗi lớp 1 sheet).
 * Hỗ trợ ánh xạ cột thông minh (Smart Header Mapping) dựa theo `expectedHeaders`.
 * Tự động lấy tên Sheet gán làm tên lớp cho các dòng trong sheet đó nếu chưa có cột lớp.
 */
export async function parseExcelOrCsvDetailed(
  file: File,
  expectedHeaders?: string[],
): Promise<ParseExcelResult> {
  const data = await file.arrayBuffer();
  const wb = XLSX.read(data, { type: "array" });
  if (!wb.SheetNames || wb.SheetNames.length === 0) {
    return { rows: [], sheets: [] };
  }

  const allRows: string[][] = [];
  const detectedSheets: DetectedSheetInfo[] = [];

  // Chuẩn bị danh sách fieldKey mục tiêu từ expectedHeaders nếu có
  const targetFieldKeys: (string | null)[] = expectedHeaders
    ? expectedHeaders.map(detectFieldKey)
    : [];

  // Xác định vị trí cột lớp trong expectedHeaders nếu có
  const classTargetIdx = targetFieldKeys.findIndex((k) => k === "className");

  for (const sheetName of wb.SheetNames) {
    const sNameNorm = normalizeHeader(sheetName);
    const isIgnoredSheet =
      sNameNorm.includes("huong dan") ||
      sNameNorm.includes("instruction") ||
      sNameNorm.includes("template") ||
      sNameNorm.includes("mau nhap") ||
      sNameNorm.includes("ghi chu") ||
      sNameNorm.includes("sample");

    if (isIgnoredSheet) continue;

    const ws = wb.Sheets[sheetName];
    if (!ws) continue;

    const rawRows: unknown[][] = XLSX.utils.sheet_to_json(ws, {
      header: 1,
      defval: "",
      blankrows: false,
    });

    const cleanRows = rawRows
      .map((row) => row.map((cell) => String(cell ?? "").trim()))
      .filter((row) => row.some((cell) => cell.length > 0));

    if (cleanRows.length === 0) continue;

    const firstRow = cleanRows[0];
    const isFirstRowData = firstRow.some((cell) => {
      const c = cell.trim();
      return (
        /\d{1,2}[h:]\d{2}/i.test(c) ||
        /^0\d{9,10}$/.test(c) ||
        /^\d{4}-\d{2}-\d{2}$/.test(c) ||
        /^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}$/.test(c)
      );
    });

    let hasHeader = false;
    if (!isFirstRowData) {
      // Dòng 1 được coi là header nếu có ít nhất 1 ô khớp với các từ khóa nhận diện
      hasHeader = firstRow.some((cell) => detectFieldKey(cell) !== null);
    }

    let dataRows = hasHeader ? cleanRows.slice(1) : cleanRows;

    // Nếu có dòng header và có expectedHeaders, tiến hành ánh xạ cột linh hoạt (Header Mapping)
    if (hasHeader && expectedHeaders && expectedHeaders.length > 0) {
      // Tạo bản đồ: fieldKey -> sourceColumnIndex trong file tải lên
      const sourceColMap = new Map<string, number>();
      firstRow.forEach((cell, idx) => {
        const detected = detectFieldKey(cell);
        if (detected && !sourceColMap.has(detected)) {
          sourceColMap.set(detected, idx);
        }
      });

      // Nếu tìm thấy ít nhất 1 cột khớp, tái cấu trúc từng dòng theo đúng thứ tự của expectedHeaders
      if (sourceColMap.size > 0) {
        dataRows = dataRows.map((row) => {
          return expectedHeaders.map((expectedH, targetIdx) => {
            const targetKey = targetFieldKeys[targetIdx];
            if (targetKey && sourceColMap.has(targetKey)) {
              const srcIdx = sourceColMap.get(targetKey)!;
              return row[srcIdx] ?? "";
            }
            // Nếu không xác định được fieldKey qua từ điển, thử so khớp chuỗi tiêu đề trực tiếp
            const directIdx = firstRow.findIndex(
              (h) => normalizeHeader(h) === normalizeHeader(expectedH),
            );
            if (directIdx !== -1) {
              return row[directIdx] ?? "";
            }
            return "";
          });
        });
      }
    }

    // Nếu file có nhiều sheet (mỗi lớp 1 sheet) hoặc tên sheet có ý nghĩa:
    // tự động chèn tên sheet vào cột Lớp nếu dòng đó chưa có thông tin lớp
    const isGenericSheet =
      /^sheet\s*\d*$/i.test(sheetName) ||
      /^trang\s*tinh\s*\d*$/i.test(sNameNorm) ||
      sNameNorm === "hocsinh" ||
      sNameNorm === "danh sach";

    const shouldUseSheetNameAsClass =
      (wb.SheetNames.length > 1 || !isGenericSheet) && sheetName.trim().length > 0;

    let sheetRowCount = 0;
    for (const r of dataRows) {
      if (shouldUseSheetNameAsClass && r.length > 0) {
        if (classTargetIdx !== -1) {
          if (!r[classTargetIdx] || !r[classTargetIdx].trim()) {
            r[classTargetIdx] = sheetName.trim();
          }
        } else {
          const col0 = (r[0] || "").toLowerCase();
          if (col0.startsWith("thứ") || col0.startsWith("t") || /^thứ\s*\d/i.test(col0)) {
            allRows.push([sheetName.trim(), ...r]);
            sheetRowCount++;
            continue;
          }
        }
      }
      allRows.push(r);
      sheetRowCount++;
    }

    if (sheetRowCount > 0) {
      detectedSheets.push({ name: sheetName.trim(), count: sheetRowCount });
    }
  }

  return { rows: allRows, sheets: detectedSheets };
}

/**
 * Đọc file Excel (.xlsx, .xls) hoặc file CSV tải lên và trả về danh sách các dòng dữ liệu.
 */
export async function parseExcelOrCsv(
  file: File,
  expectedHeaders?: string[],
): Promise<string[][]> {
  const res = await parseExcelOrCsvDetailed(file, expectedHeaders);
  return res.rows;
}

