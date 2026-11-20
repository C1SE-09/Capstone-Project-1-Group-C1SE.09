/**
 * admin-web/lib/locale-helper.ts
 * ==============================
 * Bộ tiện ích định dạng danh xưng song ngữ và từ điển Thời khóa biểu cho Web Admin.
 * Đồng bộ logic với Flutter app:
 *   - Trường Mầm Non / Kindergarten
 *   - Lớp / Class
 *   - Cô / Teacher
 *   - Từ điển hoạt động & phòng học mầm non
 */

export type Language = "vi" | "en";

/**
 * Định dạng tên trường mầm non theo ngôn ngữ.
 * Ví dụ: "Họa Mi" -> VI: "Trường Mầm Non Họa Mi", EN: "Hoa Mi Kindergarten"
 */
export function formatSchoolName(
  rawName?: string | null,
  lang: Language = "vi"
): string {
  if (!rawName || !rawName.trim()) {
    return lang === "en" ? "Kindergarten" : "Trường Mầm non";
  }

  const clean = rawName
    .replace(/^Trường\s+Mầm\s+Non\s+/i, "")
    .replace(/^Trường\s+Mầm\s+non\s+/i, "")
    .replace(/^Trường\s+MN\s+/i, "")
    .replace(/^MN\s+/i, "")
    .replace(/\s+Kindergarten$/i, "")
    .trim();

  if (!clean) {
    return lang === "en" ? "Kindergarten" : "Trường Mầm non";
  }

  if (lang === "en") {
    // Chuyển không dấu đơn giản cho tên trường quen thuộc nếu cần, hoặc giữ nguyên tên riêng
    const normalizedName = clean === "Họa Mi" ? "Hoa Mi" : clean;
    return `${normalizedName} Kindergarten`;
  }
  return `Trường Mầm Non ${clean}`;
}

/**
 * Định dạng tên lớp theo ngôn ngữ.
 * Ví dụ: "Mầm A" -> VI: "Lớp Mầm A", EN: "Class Mam A"
 */
export function formatClassName(
  rawName?: string | null,
  lang: Language = "vi"
): string {
  if (!rawName || !rawName.trim()) {
    return lang === "en" ? "Class" : "Lớp";
  }

  const clean = rawName
    .replace(/^Lớp\s+/i, "")
    .replace(/^Class\s+/i, "")
    .trim();

  if (!clean) {
    return lang === "en" ? "Class" : "Lớp";
  }

  if (lang === "en") {
    return `Class ${clean}`;
  }
  return `Lớp ${clean}`;
}

/**
 * Định dạng tên giáo viên theo ngôn ngữ.
 * Ví dụ: "Nguyễn Thị Mai" -> VI: "Cô Nguyễn Thị Mai", EN: "Teacher Nguyen Thi Mai"
 */
export function formatTeacherName(
  rawName?: string | null,
  lang: Language = "vi",
  gender?: string | null
): string {
  if (!rawName || !rawName.trim()) {
    return lang === "en" ? "Teacher" : "Giáo viên";
  }

  const clean = rawName
    .replace(/^Cô\s+/i, "")
    .replace(/^Thầy\s+/i, "")
    .replace(/^Teacher\s+/i, "")
    .trim();

  if (!clean) {
    return lang === "en" ? "Teacher" : "Giáo viên";
  }

  if (lang === "en") {
    return `Teacher ${clean}`;
  }

  const prefix = gender && gender.toLowerCase().includes("nam") ? "Thầy" : "Cô";
  return `${prefix} ${clean}`;
}

/**
 * Từ điển hoạt động mầm non chuẩn (Vietnamese -> English)
 */
const ACTIVITY_DICTIONARY: Record<string, string> = {
  "đón trẻ": "Arrival & Free Play",
  "đón trẻ & chơi tự do": "Arrival & Free Play",
  "đón trẻ - chơi tự do": "Arrival & Free Play",
  "tập thể dục - ăn sáng": "Morning Exercise & Breakfast",
  "thể dục - ăn sáng": "Morning Exercise & Breakfast",
  "thể dục buổi sáng": "Morning Exercise",
  "thể dục sáng": "Morning Exercise",
  "ăn sáng": "Breakfast",
  "hoạt động có chủ đích": "Guided Learning Activity",
  "hoạt động có chủ đích (mỹ thuật)": "Art & Craft Activity",
  "hoạt động có chủ đích (âm nhạc)": "Music & Movement Activity",
  "hoạt động có chủ đích (kỹ năng)": "Life Skills Activity",
  "hoạt động có chủ đích (tiếng việt)": "Language & Storytelling Activity",
  "hoạt động có chủ đích (toán)": "Early Math Activity",
  "hoạt động có chủ đích (khám phá)": "Science & Exploration Activity",
  "hoạt động học": "Learning Activity",
  "ăn giữa giờ - vệ sinh": "Mid-morning Snack & Hygiene",
  "ăn giữa giờ": "Mid-morning Snack",
  "uống sữa": "Milk Break",
  "hoạt động vui chơi": "Free Play & Corner Activities",
  "vui chơi tự do": "Free Play",
  "hoạt động góc": "Corner Activities",
  "hoạt động ngoài trời": "Outdoor Activities",
  "ăn trưa": "Lunch Time",
  "vệ sinh - ăn trưa": "Hygiene & Lunch",
  "ngủ trưa": "Nap Time",
  "vệ sinh & ngủ trưa": "Hygiene & Nap Time",
  "hoạt động nhẹ": "Gentle Awakening & Movement",
  "vận động nhẹ": "Gentle Movement",
  "thức dậy": "Wake-up Time",
  "ăn xế": "Afternoon Snack",
  "ăn phụ chiều": "Afternoon Snack",
  "ăn chiều": "Afternoon Meal",
  "sinh hoạt ngoại khóa - hoạt động vui chơi": "Extracurricular & Play Activities",
  "sinh hoạt ngoại khóa": "Extracurricular Activities",
  "hoạt động chiều": "Afternoon Activities",
  "trả trẻ": "Pick-up & Dismissal",
  "vệ sinh & trả trẻ": "Hygiene & Dismissal",
  "vệ sinh": "Hygiene & Clean up",
};

/**
 * Từ điển địa điểm / phòng học chuẩn
 */
const ROOM_DICTIONARY: Record<string, string> = {
  "phòng học mầm a": "Classroom Nursery A",
  "phòng học mầm b": "Classroom Nursery B",
  "phòng học mầm c": "Classroom Nursery C",
  "phòng mầm a": "Classroom Nursery A",
  "phòng mầm b": "Classroom Nursery B",
  "phòng mầm c": "Classroom Nursery C",
  "lớp mầm a": "Classroom Nursery A",
  "lớp mầm b": "Classroom Nursery B",
  "lớp mầm c": "Classroom Nursery C",
  "mầm a": "Classroom Nursery A",
  "mầm b": "Classroom Nursery B",
  "mầm c": "Classroom Nursery C",
  "phòng học": "Classroom",
  "lớp học": "Classroom",
  "tại lớp": "In Class",
  "phòng mỹ thuật & tạo hình": "Art & Craft Studio",
  "phòng mỹ thuật": "Art Studio",
  "phòng tạo hình": "Craft Studio",
  "phòng âm nhạc & vận động": "Music & Movement Room",
  "phòng âm nhạc": "Music Room",
  "phòng thể chất": "Gymnasium",
  "sân trường": "School Yard",
  "sân cỏ": "Playground / Grass Field",
  "sân chơi": "Playground",
  "hồ bơi": "Swimming Pool",
  "bể bơi": "Swimming Pool",
  "nhà ăn": "Dining Hall",
  "thư viện": "Library",
  "vườn trường": "School Garden",
  "phòng y tế": "Health Office",
};

/**
 * Ánh xạ tên hoạt động sang tiếng Anh nếu lang === 'en'.
 */
export function localizeActivityName(
  rawActivity?: string | null,
  lang: Language = "vi"
): string {
  if (!rawActivity || !rawActivity.trim()) return "";
  if (lang !== "en") return rawActivity;

  const trimmed = rawActivity.trim();
  const lower = trimmed.toLowerCase();

  if (ACTIVITY_DICTIONARY[lower]) {
    return ACTIVITY_DICTIONARY[lower];
  }

  // Khớp theo cụm từ khóa
  for (const [viKey, enVal] of Object.entries(ACTIVITY_DICTIONARY)) {
    if (lower.startsWith(viKey) || lower.includes(viKey)) {
      return trimmed.replace(new RegExp(viKey, "gi"), enVal);
    }
  }

  return trimmed;
}

/**
 * Ánh xạ tên phòng học sang tiếng Anh nếu lang === 'en'.
 */
export function localizeRoomName(
  rawRoom?: string | null,
  lang: Language = "vi"
): string {
  if (!rawRoom || !rawRoom.trim()) return "";
  if (lang !== "en") return rawRoom;

  const trimmed = rawRoom.trim();
  const lower = trimmed.toLowerCase();

  if (ROOM_DICTIONARY[lower]) {
    return ROOM_DICTIONARY[lower];
  }

  // Khớp cụm từ khóa
  for (const [viKey, enVal] of Object.entries(ROOM_DICTIONARY)) {
    if (lower.startsWith(viKey) || lower.includes(viKey)) {
      return trimmed.replace(new RegExp(viKey, "gi"), enVal);
    }
  }

  return trimmed;
}

const DAYS_VI = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"];
const DAYS_EN = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
const DAYS_SHORT_VI = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];
const DAYS_SHORT_EN = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export function getDayLabel(index: number, lang: Language = "vi"): string {
  if (lang === "en") {
    return DAYS_EN[index] || `Day ${index + 2}`;
  }
  return DAYS_VI[index] || `Thứ ${index + 2}`;
}

export function getDayShortLabel(index: number, lang: Language = "vi"): string {
  if (lang === "en") {
    return DAYS_SHORT_EN[index] || `D${index + 2}`;
  }
  return DAYS_SHORT_VI[index] || `T${index + 2}`;
}
