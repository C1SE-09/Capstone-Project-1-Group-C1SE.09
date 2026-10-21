/**
 * components/ImageViewerModal.tsx
 * =================================
 * Lightbox Modal xem hình ảnh phóng to trực tiếp trên trang admin-web.
 * Không chuyển trang, không mở tab mới.
 * Hỗ trợ zoom in/out, xoay ảnh, tải xuống, chuyển ảnh trước/sau và phím tắt.
 */

import React, { useEffect, useState, useCallback } from "react";
import { formatFileSize, resolveAttachmentUrl } from "@/lib/format";

export interface AttachmentImageItem {
  attachment_id: string;
  file_url: string;
  file_name: string;
  file_size?: number | null;
  mime_type?: string | null;
  description?: string | null;
}

interface ImageViewerModalProps {
  isOpen: boolean;
  onClose: () => void;
  images: AttachmentImageItem[];
  currentIndex: number;
  onSelectIndex: (idx: number) => void;
}

export default function ImageViewerModal({
  isOpen,
  onClose,
  images,
  currentIndex,
  onSelectIndex,
}: ImageViewerModalProps) {
  const [scale, setScale] = useState(1);
  const [rotation, setRotation] = useState(0);
  const [loading, setLoading] = useState(true);
  const [hasError, setHasError] = useState(false);

  const currentImage = images[currentIndex] || null;

  // Reset zoom & rotation khi chuyển ảnh hoặc mở modal
  useEffect(() => {
    setScale(1);
    setRotation(0);
    setLoading(true);
    setHasError(false);
  }, [currentIndex, isOpen]);

  const handlePrev = useCallback(() => {
    if (images.length <= 1) return;
    onSelectIndex((currentIndex - 1 + images.length) % images.length);
  }, [currentIndex, images.length, onSelectIndex]);

  const handleNext = useCallback(() => {
    if (images.length <= 1) return;
    onSelectIndex((currentIndex + 1) % images.length);
  }, [currentIndex, images.length, onSelectIndex]);

  const handleZoomIn = () => {
    setScale((prev) => Math.min(prev + 0.25, 3));
  };

  const handleZoomOut = () => {
    setScale((prev) => Math.max(prev - 0.25, 0.5));
  };

  const handleResetZoom = () => {
    setScale(1);
    setRotation(0);
  };

  const handleRotate = () => {
    setRotation((prev) => (prev + 90) % 360);
  };

  const handleDownload = () => {
    if (!currentImage) return;
    const url = resolveAttachmentUrl(currentImage.file_url);
    const link = document.createElement("a");
    link.href = url;
    link.download = currentImage.file_name || "image";
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Lắng nghe phím tắt: Esc để đóng, ArrowLeft/ArrowRight để chuyển ảnh, +/- để zoom
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
      } else if (e.key === "ArrowLeft") {
        handlePrev();
      } else if (e.key === "ArrowRight") {
        handleNext();
      } else if (e.key === "+" || e.key === "=") {
        handleZoomIn();
      } else if (e.key === "-") {
        handleZoomOut();
      } else if (e.key === "0") {
        handleResetZoom();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    // Khóa scroll body khi modal mở
    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = originalOverflow;
    };
  }, [isOpen, onClose, handlePrev, handleNext]);

  if (!isOpen || !currentImage) return null;

  const currentUrl = resolveAttachmentUrl(currentImage.file_url);

  return (
    <div
      className="fixed inset-0 z-[100] flex flex-col bg-black/90 backdrop-blur-sm select-none"
      onClick={(e) => {
        // Đóng khi click vào vùng nền trống
        if (e.target === e.currentTarget) {
          onClose();
        }
      }}
    >
      {/* ─── Header bar ──────────────────────────────────────── */}
      <div className="flex items-center justify-between px-6 py-3 bg-neutral-900/80 border-b border-neutral-800 text-white z-10">
        <div className="flex items-center gap-3 min-w-0 pr-4">
          <div className="w-8 h-8 rounded-lg bg-teal-900/60 text-teal-400 flex items-center justify-center text-base font-bold shrink-0">
            🖼️
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <h4 className="text-sm font-semibold truncate text-neutral-100 max-w-xs md:max-w-md">
                {currentImage.file_name}
              </h4>
              {images.length > 1 && (
                <span className="text-xs px-2 py-0.5 rounded-full bg-neutral-800 text-neutral-300 shrink-0 font-medium">
                  {currentIndex + 1} / {images.length}
                </span>
              )}
            </div>
            <div className="text-xs text-neutral-400 flex items-center gap-2 mt-0.5">
              {currentImage.file_size && (
                <span>{formatFileSize(currentImage.file_size)}</span>
              )}
              {currentImage.mime_type && (
                <>
                  <span>•</span>
                  <span>{currentImage.mime_type}</span>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Toolbar điều khiển */}
        <div className="flex items-center gap-1.5 shrink-0">
          {/* Zoom controls */}
          <div className="hidden sm:flex items-center bg-neutral-800 rounded-lg p-0.5 border border-neutral-700/60">
            <button
              onClick={handleZoomOut}
              disabled={scale <= 0.5}
              title="Thu nhỏ (-)"
              className="px-2.5 py-1 text-xs text-neutral-300 hover:text-white disabled:opacity-40 disabled:hover:text-neutral-300 transition-colors"
            >
              －
            </button>
            <button
              onClick={handleResetZoom}
              title="Đặt lại tỉ lệ (0)"
              className="px-2 py-1 text-xs font-mono text-teal-400 hover:text-teal-300 transition-colors"
            >
              {Math.round(scale * 100)}%
            </button>
            <button
              onClick={handleZoomIn}
              disabled={scale >= 3}
              title="Phóng to (+)"
              className="px-2.5 py-1 text-xs text-neutral-300 hover:text-white disabled:opacity-40 disabled:hover:text-neutral-300 transition-colors"
            >
              ＋
            </button>
          </div>

          {/* Rotate */}
          <button
            onClick={handleRotate}
            title="Xoay ảnh 90°"
            className="p-2 rounded-lg bg-neutral-800 hover:bg-neutral-700 text-neutral-200 transition-colors flex items-center justify-center"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67" />
            </svg>
          </button>

          {/* Download */}
          <button
            onClick={handleDownload}
            title="Tải ảnh về máy"
            className="p-2 rounded-lg bg-neutral-800 hover:bg-neutral-700 text-neutral-200 transition-colors flex items-center justify-center"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3" />
            </svg>
          </button>

          {/* Close button */}
          <button
            onClick={onClose}
            title="Đóng (Esc)"
            className="p-2 rounded-lg bg-red-600/80 hover:bg-red-600 text-white transition-colors ml-1 flex items-center justify-center font-bold"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>
      </div>

      {/* ─── Body Canvas hiển thị ảnh ────────────────────────── */}
      <div
        className="flex-1 relative flex items-center justify-center p-4 overflow-hidden"
        onClick={(e) => {
          if (e.target === e.currentTarget) {
            onClose();
          }
        }}
      >
        {/* Nút lùi ảnh Trước (‹) */}
        {images.length > 1 && (
          <button
            onClick={(e) => {
              e.stopPropagation();
              handlePrev();
            }}
            title="Ảnh trước (Mũi tên trái ←)"
            className="absolute left-4 top-1/2 -translate-y-1/2 z-20 w-11 h-11 rounded-full bg-neutral-900/80 hover:bg-neutral-800 text-white border border-neutral-700/60 flex items-center justify-center text-2xl shadow-xl transition-transform hover:scale-110 active:scale-95"
          >
            ‹
          </button>
        )}

        {/* Loading Spinner */}
        {loading && !hasError && (
          <div className="absolute inset-0 flex items-center justify-center z-10">
            <div className="flex flex-col items-center gap-3 bg-neutral-900/80 px-5 py-4 rounded-xl border border-neutral-800 text-neutral-300">
              <div className="w-8 h-8 border-3 border-teal-500 border-t-transparent rounded-full animate-spin" />
              <span className="text-xs font-medium">Đang tải hình ảnh...</span>
            </div>
          </div>
        )}

        {/* Thông báo lỗi khi không load được ảnh */}
        {hasError ? (
          <div className="flex flex-col items-center gap-3 bg-neutral-900/90 p-8 rounded-2xl border border-neutral-800 text-center max-w-md shadow-2xl">
            <div className="text-4xl">⚠️</div>
            <h5 className="text-base font-semibold text-neutral-200">
              Không thể tải hình ảnh
            </h5>
            <p className="text-xs text-neutral-400 leading-relaxed">
              Địa chỉ hình ảnh không phản hồi hoặc đã bị thay đổi:
              <br />
              <span className="font-mono text-neutral-500 break-all text-[11px] block mt-1">
                {currentUrl}
              </span>
            </p>
            <div className="flex items-center gap-2 mt-2">
              <button
                onClick={() => {
                  setHasError(false);
                  setLoading(true);
                }}
                className="px-3 py-1.5 rounded-lg bg-teal-600 hover:bg-teal-500 text-white text-xs font-medium transition-colors"
              >
                Thử lại
              </button>
              <button
                onClick={onClose}
                className="px-3 py-1.5 rounded-lg bg-neutral-800 hover:bg-neutral-700 text-neutral-300 text-xs font-medium transition-colors"
              >
                Đóng
              </button>
            </div>
          </div>
        ) : (
          /* Hình ảnh lớn */
          <div
            className="flex items-center justify-center max-h-full max-w-full transition-transform duration-200 ease-out"
            style={{
              transform: `scale(${scale}) rotate(${rotation}deg)`,
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={currentUrl}
              alt={currentImage.file_name}
              onLoad={() => setLoading(false)}
              onError={() => {
                setLoading(false);
                setHasError(true);
              }}
              className="max-h-[78vh] max-w-[90vw] object-contain rounded-lg shadow-2xl transition-opacity duration-200"
              style={{ opacity: loading ? 0 : 1 }}
            />
          </div>
        )}

        {/* Nút tiến ảnh Sau (›) */}
        {images.length > 1 && (
          <button
            onClick={(e) => {
              e.stopPropagation();
              handleNext();
            }}
            title="Ảnh kế tiếp (Mũi tên phải →)"
            className="absolute right-4 top-1/2 -translate-y-1/2 z-20 w-11 h-11 rounded-full bg-neutral-900/80 hover:bg-neutral-800 text-white border border-neutral-700/60 flex items-center justify-center text-2xl shadow-xl transition-transform hover:scale-110 active:scale-95"
          >
            ›
          </button>
        )}
      </div>

      {/* ─── Dải thumbnail phía dưới (nếu có > 1 ảnh) ───────── */}
      {images.length > 1 && (
        <div className="px-4 py-3 bg-neutral-900/90 border-t border-neutral-800 flex items-center justify-center gap-2 overflow-x-auto z-10">
          {images.map((img, idx) => {
            const isSelected = idx === currentIndex;
            const thumbUrl = resolveAttachmentUrl(img.file_url);
            return (
              <button
                key={img.attachment_id || idx}
                onClick={() => onSelectIndex(idx)}
                className={`relative w-14 h-14 rounded-lg overflow-hidden border-2 transition-all shrink-0 ${
                  isSelected
                    ? "border-teal-400 scale-105 shadow-md"
                    : "border-neutral-700 opacity-60 hover:opacity-100"
                }`}
                title={img.file_name}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={thumbUrl}
                  alt={img.file_name}
                  className="w-full h-full object-cover"
                  onError={(e) => {
                    // Fallback sang icon nếu thumbnail lỗi
                    (e.target as HTMLElement).style.display = "none";
                  }}
                />
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
