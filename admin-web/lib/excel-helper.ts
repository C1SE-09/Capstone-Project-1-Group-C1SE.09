/**
 * lib/excel-helper.ts
 * ===================
 * Tiện ích xuất / nhập dữ liệu Excel (.xlsx) & CSV dùng thư viện xlsx (SheetJS).
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
 * Xuất dữ liệu ra file Excel (.xlsx) và kích hoạt tải về trên trình duyệt.
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
 * Đọc file Excel (.xlsx, .xls) hoặc file CSV tải lên và trả về danh sách các dòng dữ liệu.
 */
export async function parseExcelOrCsv(file: File): Promise<string[][]> {
  const data = await file.arrayBuffer();
  const wb = XLSX.read(data, { type: "array" });
  const firstSheetName = wb.SheetNames[0];
  if (!firstSheetName) return [];

  const ws = wb.Sheets[firstSheetName];
  const rawRows: unknown[][] = XLSX.utils.sheet_to_json(ws, {
    header: 1,
    defval: "",
    blankrows: false,
  });

  const cleanRows = rawRows
    .map((row) => row.map((cell) => String(cell ?? "").trim()))
    .filter((row) => row.some((cell) => cell.length > 0));

  // Loại bỏ dòng header đầu tiên nếu có chứa tiêu đề
  if (cleanRows.length > 0) {
    const firstRowText = cleanRows[0].join(" ").toLowerCase();
    if (
      firstRowText.includes("họ") ||
      firstRowText.includes("name") ||
      firstRowText.includes("tên") ||
      firstRowText.includes("thứ") ||
      firstRowText.includes("lớp") ||
      firstRowText.includes("khung giờ") ||
      firstRowText.includes("hoạt động")
    ) {
      return cleanRows.slice(1);
    }
  }

  return cleanRows;
}
