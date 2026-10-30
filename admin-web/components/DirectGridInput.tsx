import React, { useCallback, useEffect, useRef, useState } from "react";

export interface DirectGridInputProps {
  headers: string[];
  sampleRow?: string[];
  rows: string[][];
  onChange: (rows: string[][]) => void;
  minRows?: number;
  disabled?: boolean;
}

/**
 * Component bảng nhập dữ liệu trực tiếp trên Web (Spreadsheet Grid).
 * Hỗ trợ:
 * - Nhập trực tiếp từng ô
 * - Dán (Ctrl+V) dữ liệu sao chép từ Microsoft Excel hoặc Google Sheets
 * - Thêm / xóa dòng linh hoạt
 * - Tự động mở rộng dòng khi dán dữ liệu lớn
 */
export function DirectGridInput({
  headers,
  sampleRow,
  rows,
  onChange,
  minRows = 5,
  disabled = false,
}: DirectGridInputProps) {
  const [activeCell, setActiveCell] = useState<{ row: number; col: number } | null>(null);
  const [pasteModalOpen, setPasteModalOpen] = useState(false);
  const [pasteText, setPasteText] = useState("");
  const tableRef = useRef<HTMLDivElement>(null);

  // Đảm bảo số dòng tối thiểu khi khởi tạo
  useEffect(() => {
    if (rows.length < minRows) {
      const needed = minRows - rows.length;
      const emptyRow = () => headers.map(() => "");
      const newRows = [...rows];
      for (let i = 0; i < needed; i++) {
        newRows.push(emptyRow());
      }
      onChange(newRows);
    }
  }, [headers, minRows, rows, onChange]);

  // Cập nhật giá trị 1 ô
  const handleCellChange = useCallback(
    (rowIndex: number, colIndex: number, value: string) => {
      const next = rows.map((r, rIdx) => {
        if (rIdx !== rowIndex) return r;
        const newCols = [...r];
        newCols[colIndex] = value;
        return newCols;
      });
      onChange(next);
    },
    [rows, onChange],
  );

  // Thêm n dòng trống
  const handleAddRows = useCallback(
    (count: number = 1) => {
      const emptyRow = () => headers.map(() => "");
      const added: string[][] = [];
      for (let i = 0; i < count; i++) {
        added.push(emptyRow());
      }
      onChange([...rows, ...added]);
    },
    [headers, rows, onChange],
  );

  // Xóa 1 dòng
  const handleDeleteRow = useCallback(
    (index: number) => {
      if (rows.length <= 1) {
        // Nếu chỉ còn 1 dòng thì reset về rỗng
        onChange([headers.map(() => "")]);
        return;
      }
      const next = rows.filter((_, idx) => idx !== index);
      onChange(next);
    },
    [headers, rows, onChange],
  );

  // Xóa trắng toàn bộ bảng
  const handleClearAll = useCallback(() => {
    const emptyRows: string[][] = [];
    for (let i = 0; i < minRows; i++) {
      emptyRows.push(headers.map(() => ""));
    }
    onChange(emptyRows);
  }, [headers, minRows, onChange]);

  // Loại bỏ các dòng trống hoàn toàn
  const handleRemoveEmptyRows = useCallback(() => {
    const nonEmpty = rows.filter((r) => r.some((c) => c && c.trim().length > 0));
    if (nonEmpty.length === 0) {
      handleClearAll();
    } else {
      onChange(nonEmpty);
    }
  }, [rows, handleClearAll, onChange]);

  // Điền thử 1 dòng mẫu
  const handleFillSample = useCallback(() => {
    if (!sampleRow || sampleRow.length === 0) return;
    // Tìm dòng trống đầu tiên hoặc thêm mới
    const emptyRowIndex = rows.findIndex((r) => r.every((c) => !c || c.trim() === ""));
    const sampleCopy = headers.map((_, idx) => sampleRow[idx] || "");
    if (emptyRowIndex !== -1) {
      const next = [...rows];
      next[emptyRowIndex] = sampleCopy;
      onChange(next);
    } else {
      onChange([...rows, sampleCopy]);
    }
  }, [sampleRow, headers, rows, onChange]);

  // Phân tích văn bản paste (từ Excel/TSV/CSV) và áp dụng vào bảng
  const applyPastedData = useCallback(
    (rawText: string, startRow = 0, startCol = 0) => {
      if (!rawText || !rawText.trim()) return;

      // Chuẩn hóa dòng: chia theo \r\n hoặc \n
      const lines = rawText.split(/\r\n|\r|\n/);
      const parsedMatrix: string[][] = [];

      for (const line of lines) {
        if (!line && parsedMatrix.length === lines.length - 1) continue; // Bỏ dòng trắng cuối
        // Excel copy vào clipboard theo định dạng TSV (tab-separated)
        // Nếu không có tab thì thử theo dấu phẩy (CSV)
        let cells: string[];
        if (line.includes("\t")) {
          cells = line.split("\t");
        } else if (line.includes(",") && !line.includes("\t")) {
          cells = line.split(",").map((s) => s.replace(/^"|"$/g, "").trim());
        } else {
          cells = [line];
        }
        parsedMatrix.push(cells);
      }

      if (parsedMatrix.length === 0) return;

      // Sao chép rows hiện tại
      const next = rows.map((r) => [...r]);

      parsedMatrix.forEach((pRow, pRIdx) => {
        const targetRIdx = startRow + pRIdx;
        while (next.length <= targetRIdx) {
          next.push(headers.map(() => ""));
        }
        pRow.forEach((val, pCIdx) => {
          const targetCIdx = startCol + pCIdx;
          if (targetCIdx < headers.length) {
            next[targetRIdx][targetCIdx] = val.trim();
          }
        });
      });

      onChange(next);
    },
    [rows, headers, onChange],
  );

  // Xử lý sự kiện Paste trên toàn bảng
  const handlePasteEvent = useCallback(
    (e: React.ClipboardEvent) => {
      const pasteData = e.clipboardData.getData("text");
      if (!pasteData) return;

      // Nếu có tab hoặc nhiều dòng, coi là paste bảng Excel
      if (pasteData.includes("\t") || pasteData.includes("\n")) {
        e.preventDefault();
        const sRow = activeCell ? activeCell.row : 0;
        const sCol = activeCell ? activeCell.col : 0;
        applyPastedData(pasteData, sRow, sCol);
      }
    },
    [activeCell, applyPastedData],
  );

  // Đếm các dòng có ít nhất 1 ô có dữ liệu
  const validRowCount = rows.filter((r) => r.some((c) => c && c.trim().length > 0)).length;

  return (
    <div className="space-y-3" onPaste={handlePasteEvent}>
      {/* Thanh công cụ bảng */}
      <div className="flex flex-wrap items-center justify-between gap-2 bg-sunken/40 p-2.5 rounded-card border border-line text-xs">
        <div className="flex flex-wrap items-center gap-1.5">
          <button
            type="button"
            disabled={disabled}
            onClick={() => handleAddRows(1)}
            className="kbtn kbtn-secondary text-xs px-2.5 py-1 flex items-center gap-1 hover:border-brand"
            title="Thêm một dòng trống vào cuối bảng"
          >
            <span>+</span> 1 dòng
          </button>
          <button
            type="button"
            disabled={disabled}
            onClick={() => handleAddRows(5)}
            className="kbtn kbtn-secondary text-xs px-2.5 py-1 flex items-center gap-1 hover:border-brand"
            title="Thêm 5 dòng trống vào cuối bảng"
          >
            <span>+</span> 5 dòng
          </button>
          <button
            type="button"
            disabled={disabled || validRowCount === 0}
            onClick={handleRemoveEmptyRows}
            className="kbtn kbtn-secondary text-xs px-2.5 py-1 text-ink-soft hover:text-ink"
            title="Loại bỏ các dòng hoàn toàn không có dữ liệu"
          >
            🧹 Lọc dòng trống
          </button>
          <button
            type="button"
            disabled={disabled || rows.length === 0}
            onClick={handleClearAll}
            className="kbtn kbtn-secondary text-xs px-2.5 py-1 text-bad hover:bg-bad/10 hover:border-bad"
            title="Xóa toàn bộ dữ liệu trong bảng để nhập lại từ đầu"
          >
            🗑 Xóa trắng
          </button>
        </div>

        <div className="flex items-center gap-2">
          {sampleRow && sampleRow.length > 0 && (
            <button
              type="button"
              disabled={disabled}
              onClick={handleFillSample}
              className="kbtn kbtn-ghost text-xs px-2 py-1 text-brand hover:bg-brand/10"
              title="Điền thử 1 dòng mẫu gợi ý vào bảng"
            >
              ✨ Điền dòng mẫu
            </button>
          )}
          <button
            type="button"
            disabled={disabled}
            onClick={() => setPasteModalOpen(true)}
            className="kbtn kbtn-secondary text-xs px-2.5 py-1 flex items-center gap-1 bg-white"
            title="Dán nhanh văn bản copy từ Excel nếu phím tắt Ctrl+V bị chặn"
          >
            📋 Dán từ Excel
          </button>
        </div>
      </div>

      {/* Thông tin số dòng & hướng dẫn */}
      <div className="flex items-center justify-between text-xs px-1 text-ink-soft">
        <div>
          <span>Đang có </span>
          <strong className="text-brand font-bold">{validRowCount}</strong> dòng có dữ liệu /{" "}
          <span>{rows.length} hàng</span>
        </div>
        <div className="text-[11px] text-ink-faint italic hidden sm:block">
          💡 Mẹo: Bạn có thể copy nhiều hàng từ Excel rồi bấm <kbd className="px-1 py-0.5 bg-sunken rounded border border-line text-[10px] font-mono">Ctrl + V</kbd> để dán tự động.
        </div>
      </div>

      {/* Bảng nhập trực tiếp dạng Spreadsheet */}
      <div
        ref={tableRef}
        className="border border-line rounded-card overflow-hidden bg-white shadow-xs max-h-[380px] overflow-x-auto overflow-y-auto"
      >
        <table className="w-full text-xs border-collapse">
          <thead className="bg-sunken text-ink font-semibold sticky top-0 z-10 select-none shadow-xs">
            <tr className="border-b border-line">
              <th className="w-10 px-2 py-2 text-center text-ink-faint font-normal bg-sunken border-r border-line shrink-0">
                #
              </th>
              {headers.map((h, i) => (
                <th
                  key={i}
                  className="px-2.5 py-2 text-left whitespace-nowrap border-r border-line last:border-r-0 min-w-[140px]"
                >
                  <span className="font-semibold text-ink">{h}</span>
                </th>
              ))}
              <th className="w-10 px-2 py-2 text-center bg-sunken border-l border-line shrink-0">
                Xóa
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-line">
            {rows.map((row, rIdx) => {
              const hasData = row.some((c) => c && c.trim().length > 0);
              return (
                <tr
                  key={rIdx}
                  className={`hover:bg-brand/5 transition-colors ${
                    hasData ? "bg-white" : "bg-sunken/15"
                  }`}
                >
                  {/* Số thứ tự dòng */}
                  <td className="px-2 py-1 text-center text-[11px] text-ink-faint bg-sunken/40 font-mono border-r border-line select-none">
                    {rIdx + 1}
                  </td>

                  {/* Các ô nhập liệu */}
                  {headers.map((_, cIdx) => (
                    <td key={cIdx} className="p-0 border-r border-line last:border-r-0 relative">
                      <input
                        type="text"
                        value={row[cIdx] || ""}
                        disabled={disabled}
                        placeholder={sampleRow?.[cIdx] ? `vd: ${sampleRow[cIdx]}` : ""}
                        onChange={(e) => handleCellChange(rIdx, cIdx, e.target.value)}
                        onFocus={() => setActiveCell({ row: rIdx, col: cIdx })}
                        className="w-full px-2.5 py-1.5 text-xs text-ink bg-transparent focus:bg-brand/5 focus:outline-hidden focus:ring-1 focus:ring-brand border-0 transition-colors"
                      />
                    </td>
                  ))}

                  {/* Nút xóa dòng */}
                  <td className="px-1 py-1 text-center border-l border-line">
                    <button
                      type="button"
                      disabled={disabled}
                      onClick={() => handleDeleteRow(rIdx)}
                      className="w-6 h-6 inline-flex items-center justify-center rounded text-ink-faint hover:text-bad hover:bg-bad/10 transition-colors"
                      title={`Xóa dòng ${rIdx + 1}`}
                    >
                      ×
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Modal dán nhanh văn bản nếu trình duyệt hạn chế clipboard */}
      {pasteModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-xs p-4">
          <div className="bg-white rounded-card border border-line shadow-lg max-w-md w-full p-4 space-y-3 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between border-b border-line pb-2">
              <h4 className="text-sm font-bold text-ink flex items-center gap-1.5">
                <span>📋</span> Dán dữ liệu sao chép từ Excel
              </h4>
              <button
                type="button"
                onClick={() => setPasteModalOpen(false)}
                className="text-ink-soft hover:text-ink text-base px-1"
              >
                ✕
              </button>
            </div>
            <p className="text-xs text-ink-soft">
              Nhấp chuột vào ô bên dưới và nhấn <kbd className="px-1 py-0.5 bg-sunken rounded border border-line text-[11px] font-mono">Ctrl + V</kbd> (hoặc chuột phải chọn Paste) để dán dữ liệu:
            </p>
            <textarea
              rows={6}
              value={pasteText}
              onChange={(e) => setPasteText(e.target.value)}
              placeholder="Dán các hàng được copy từ Excel hoặc Google Sheets vào đây..."
              className="w-full p-2.5 text-xs font-mono rounded-control border border-line focus:border-brand focus:ring-1 focus:ring-brand outline-hidden resize-none bg-sunken/30"
              autoFocus
            />
            <div className="flex justify-end gap-2 pt-1 border-t border-line">
              <button
                type="button"
                onClick={() => {
                  setPasteText("");
                  setPasteModalOpen(false);
                }}
                className="kbtn kbtn-secondary text-xs"
              >
                Hủy
              </button>
              <button
                type="button"
                disabled={!pasteText.trim()}
                onClick={() => {
                  applyPastedData(pasteText, activeCell?.row || 0, activeCell?.col || 0);
                  setPasteText("");
                  setPasteModalOpen(false);
                }}
                className="kbtn kbtn-primary text-xs"
              >
                Áp dụng vào bảng
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

