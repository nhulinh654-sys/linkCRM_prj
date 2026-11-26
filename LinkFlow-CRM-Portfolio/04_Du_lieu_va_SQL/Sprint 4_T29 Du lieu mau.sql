-- LinkFlow CRM - Dữ liệu mẫu cho T-29 (dự án mô phỏng / cá nhân)
-- Toàn bộ dữ liệu là HƯ CẤU, dựng theo ERD T-13 v0.3 và khớp bộ dữ liệu ở mục 9 của T-28 v0.2.
-- Cách chạy (PostgreSQL 12 trở lên): tạo database trống rồi chạy file này, ví dụ  psql -d linkflow -f "Sprint 4_T29 Du lieu mau.sql"  hoặc dán vào pgAdmin / DBeaver.
-- Quy ước: TIMESTAMP lưu chuỗi 'YYYY-MM-DD HH:MM:SS'; tiền tính bằng đồng.
-- Thời điểm xem báo cáo (as-of) dùng trong T-28: 2026-11-06 09:30 (thứ Sáu). Tháng M = 10/2026, M+1 = 11/2026.
-- Các bảng không phục vụ báo cáo (IMPORT_BATCH, CONTACT, INTERACTION, TASK, DELIVERY, DELIVERY_HISTORY, DISCOUNT_APPROVAL, NOTIFICATION) được tạo nhưng để trống.



DROP TABLE IF EXISTS notification CASCADE; DROP TABLE IF EXISTS delivery_history CASCADE; DROP TABLE IF EXISTS discount_approval CASCADE;
DROP TABLE IF EXISTS payment CASCADE; DROP TABLE IF EXISTS delivery CASCADE; DROP TABLE IF EXISTS handoff CASCADE; DROP TABLE IF EXISTS task CASCADE;
DROP TABLE IF EXISTS interaction CASCADE; DROP TABLE IF EXISTS deal_stage_history CASCADE; DROP TABLE IF EXISTS deal CASCADE; DROP TABLE IF EXISTS lost_reason CASCADE;
DROP TABLE IF EXISTS contact CASCADE; DROP TABLE IF EXISTS lead CASCADE; DROP TABLE IF EXISTS account CASCADE; DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS import_batch CASCADE; DROP TABLE IF EXISTS source_campaign CASCADE;

CREATE TABLE source_campaign (source_id INTEGER PRIMARY KEY, kenh VARCHAR(30) NOT NULL, ten_chien_dich VARCHAR(100));
CREATE TABLE users (user_id INTEGER PRIMARY KEY, ho_ten VARCHAR(100) NOT NULL, email VARCHAR(100) NOT NULL UNIQUE,
  vai_tro VARCHAR(20) NOT NULL CHECK (vai_tro IN ('giam_doc','truong_phong_kd','nhan_vien_kd','marketing','ky_thuat','ke_toan','cskh')),
  dang_hoat_dong BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE import_batch (import_batch_id INTEGER PRIMARY KEY, ten_file VARCHAR(150) NOT NULL, nguoi_nhap INTEGER NOT NULL REFERENCES users(user_id),
  thoi_diem TIMESTAMP NOT NULL, tong_so_dong INTEGER NOT NULL, so_dong_thanh_cong INTEGER NOT NULL, so_dong_loi INTEGER NOT NULL, so_dong_trung INTEGER NOT NULL);
CREATE TABLE account (account_id INTEGER PRIMARY KEY, ten_thuong_goi VARCHAR(150) NOT NULL, ten_chuan_hoa VARCHAR(150) NOT NULL,
  ten_phap_ly VARCHAR(200), ma_so_thue VARCHAR(14) UNIQUE, dia_chi_phap_ly VARCHAR(255), email_hoa_don VARCHAR(100),
  nganh VARCHAR(50), khu_vuc VARCHAR(50), source_id INTEGER NOT NULL REFERENCES source_campaign(source_id),
  owner_id INTEGER REFERENCES users(user_id), import_batch_id INTEGER REFERENCES import_batch(import_batch_id),
  ngay_tao TIMESTAMP NOT NULL, tao_boi INTEGER NOT NULL REFERENCES users(user_id),
  hoa_don_chuyen_luc TIMESTAMP, hoa_don_chuyen_boi INTEGER REFERENCES users(user_id));
CREATE TABLE contact (contact_id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES account(account_id), ho_ten VARCHAR(100) NOT NULL,
  chuc_vu VARCHAR(50), sdt VARCHAR(15) NOT NULL, email VARCHAR(100), la_dau_moi BOOLEAN NOT NULL DEFAULT FALSE);
CREATE TABLE lead (lead_id INTEGER PRIMARY KEY, source_id INTEGER NOT NULL REFERENCES source_campaign(source_id), ten_cong_ty VARCHAR(150) NOT NULL,
  nguoi_lien_he VARCHAR(100), sdt VARCHAR(15) NOT NULL, email VARCHAR(100), ghi_chu VARCHAR(500),
  assigned_to INTEGER REFERENCES users(user_id), ngay_tao TIMESTAMP NOT NULL, ngay_phan_bo TIMESTAMP,
  trang_thai VARCHAR(20) NOT NULL CHECK (trang_thai IN ('moi','da_phan_bo','da_chuyen_deal','khong_dat')),
  ly_do_khong_dat VARCHAR(30) CHECK (ly_do_khong_dat IN ('khong_lien_lac_duoc','sai_thong_tin','khong_co_nhu_cau','khac')),
  account_id INTEGER REFERENCES account(account_id));
CREATE TABLE lost_reason (ly_do_thua_id INTEGER PRIMARY KEY, ten_ly_do VARCHAR(100) NOT NULL, nhom VARCHAR(50) NOT NULL, con_dung BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE deal (deal_id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES account(account_id), owner_id INTEGER NOT NULL REFERENCES users(user_id),
  source_id INTEGER NOT NULL REFERENCES source_campaign(source_id),
  lead_id INTEGER REFERENCES lead(lead_id),                      -- v0.3 (CR-01): trống nếu deal không đến từ lead
  giai_doan VARCHAR(10) NOT NULL CHECK (giai_doan IN ('lien_he','tu_van','bao_gia','dam_phan','da_ky','thua')),
  ngay_vao_giai_doan TIMESTAMP NOT NULL, gia_tri DECIMAL(15,0), goi_dich_vu VARCHAR(100), ngay_ky DATE,
  ly_do_thua_id INTEGER REFERENCES lost_reason(ly_do_thua_id), ghi_chu_thua VARCHAR(500), ngay_tao TIMESTAMP NOT NULL,
  CONSTRAINT ck_deal_da_ky_co_ngay_ky CHECK (giai_doan <> 'da_ky' OR ngay_ky IS NOT NULL),   -- T-13 v0.4
  CONSTRAINT ck_deal_thua_co_ly_do CHECK (giai_doan <> 'thua' OR ly_do_thua_id IS NOT NULL));
CREATE TABLE deal_stage_history (history_id INTEGER PRIMARY KEY, deal_id INTEGER NOT NULL REFERENCES deal(deal_id), tu_giai_doan VARCHAR(10),
  den_giai_doan VARCHAR(10) NOT NULL, nguoi_doi INTEGER NOT NULL REFERENCES users(user_id), thoi_diem TIMESTAMP NOT NULL);
CREATE TABLE interaction (interaction_id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES account(account_id), deal_id INTEGER REFERENCES deal(deal_id),
  user_id INTEGER NOT NULL REFERENCES users(user_id), thoi_diem TIMESTAMP NOT NULL,
  kenh VARCHAR(20) NOT NULL CHECK (kenh IN ('goi_dien','zalo','gap_truc_tiep','email')),
  ket_qua VARCHAR(20) NOT NULL CHECK (ket_qua IN ('quan_tam','can_bao_gia','can_nhac','tu_choi')), hen_lan_sau TIMESTAMP, ghi_chu VARCHAR(500));
CREATE TABLE task (task_id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(user_id), interaction_id INTEGER REFERENCES interaction(interaction_id),
  noi_dung VARCHAR(200) NOT NULL, han_xu_ly TIMESTAMP NOT NULL, trang_thai VARCHAR(10) NOT NULL CHECK (trang_thai IN ('chua_lam','da_xong')), hoan_thanh_luc TIMESTAMP);
CREATE TABLE handoff (handoff_id INTEGER PRIMARY KEY, deal_id INTEGER NOT NULL REFERENCES deal(deal_id), cong SMALLINT NOT NULL CHECK (cong IN (2,3)),
  gui_boi INTEGER NOT NULL REFERENCES users(user_id), gui_luc TIMESTAMP NOT NULL, han_sla TIMESTAMP,
  xac_nhan_boi INTEGER REFERENCES users(user_id), xac_nhan_luc TIMESTAMP, tra_lai_boi INTEGER REFERENCES users(user_id), tra_lai_luc TIMESTAMP,
  ly_do_tra_lai VARCHAR(30), ghi_chu_tra_lai VARCHAR(255));
CREATE TABLE delivery (delivery_id INTEGER PRIMARY KEY, deal_id INTEGER NOT NULL UNIQUE REFERENCES deal(deal_id), dia_chi_lap_dat VARCHAR(255) NOT NULL,
  nguoi_lien_he_tai_cho VARCHAR(100) NOT NULL, sdt_tai_cho VARCHAR(15) NOT NULL, khung_gio_tiep_can VARCHAR(100) NOT NULL, luu_y_ha_tang VARCHAR(255),
  trang_thai VARCHAR(25) NOT NULL CHECK (trang_thai IN ('cho_nhan_ban_giao','da_nhan_ban_giao','dang_khao_sat','dang_lap_dat','da_nghiem_thu')), ngay_nghiem_thu DATE);
CREATE TABLE payment (payment_id INTEGER PRIMARY KEY, deal_id INTEGER NOT NULL REFERENCES deal(deal_id), loai VARCHAR(10) NOT NULL CHECK (loai IN ('coc','tat_toan')),
  so_tien DECIMAL(15,0) NOT NULL, ngay_thu DATE NOT NULL, xac_nhan_boi INTEGER NOT NULL REFERENCES users(user_id), xac_nhan_luc TIMESTAMP NOT NULL,
  CONSTRAINT uq_payment_deal_loai UNIQUE (deal_id, loai));                                   -- T-13 v0.4: tối đa 2 dòng mỗi deal
CREATE TABLE discount_approval (approval_id INTEGER PRIMARY KEY, deal_id INTEGER NOT NULL REFERENCES deal(deal_id), ty_le_giam DECIMAL(5,2) NOT NULL,
  nguoi_de_nghi INTEGER NOT NULL REFERENCES users(user_id), ngay_de_nghi TIMESTAMP NOT NULL, nguoi_duyet INTEGER REFERENCES users(user_id), ngay_duyet TIMESTAMP,
  trang_thai VARCHAR(10) NOT NULL CHECK (trang_thai IN ('cho_duyet','da_duyet','tu_choi')), ghi_chu VARCHAR(255));
CREATE TABLE delivery_history (history_id INTEGER PRIMARY KEY, delivery_id INTEGER NOT NULL REFERENCES delivery(delivery_id), tu_trang_thai VARCHAR(25),
  den_trang_thai VARCHAR(25) NOT NULL, nguoi_cap_nhat INTEGER NOT NULL REFERENCES users(user_id), thoi_diem TIMESTAMP NOT NULL, ghi_chu VARCHAR(500));
CREATE TABLE notification (notification_id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(user_id), loai VARCHAR(25) NOT NULL,
  doi_tuong_loai VARCHAR(10) NOT NULL CHECK (doi_tuong_loai IN ('lead','handoff','account')), doi_tuong_id INTEGER NOT NULL, noi_dung VARCHAR(300) NOT NULL,
  tao_luc TIMESTAMP NOT NULL, da_doc BOOLEAN NOT NULL DEFAULT FALSE, doc_luc TIMESTAMP);
CREATE UNIQUE INDEX uq_handoff_hieu_luc ON handoff(deal_id, cong) WHERE tra_lai_luc IS NULL;    -- T-13 v0.4: một form hiệu lực mỗi deal và cổng
CREATE INDEX ix_deal_gd ON deal(giai_doan); CREATE INDEX ix_deal_lead ON deal(lead_id); CREATE INDEX ix_pay_deal ON payment(deal_id);

BEGIN;
-- ===== Danh mục và người dùng =====
INSERT INTO source_campaign (source_id, kenh, ten_chien_dich) VALUES
  (1, 'Facebook Ads', 'Khai trương'),
  (2, 'Zalo', NULL),
  (3, 'Hotline', NULL),
  (4, 'Chưa xác định', NULL);

INSERT INTO users (user_id, ho_ten, email, vai_tro, dang_hoat_dong) VALUES
  (1, 'Giám đốc (mẫu)', 'giamdoc@example.com', 'giam_doc', TRUE),
  (2, 'Lan', 'lan@example.com', 'nhan_vien_kd', TRUE),
  (3, 'Hùng', 'hung@example.com', 'nhan_vien_kd', TRUE),
  (4, 'Trưởng phòng KD (mẫu)', 'tpkd@example.com', 'truong_phong_kd', TRUE),
  (5, 'Marketing (mẫu)', 'mkt@example.com', 'marketing', TRUE),
  (6, 'Kỹ thuật (mẫu)', 'kythuat@example.com', 'ky_thuat', TRUE),
  (7, 'Kế toán (mẫu)', 'ketoan@example.com', 'ke_toan', TRUE),
  (8, 'CSKH (mẫu)', 'cskh@example.com', 'cskh', TRUE);

INSERT INTO lost_reason (ly_do_thua_id, ten_ly_do, nhom, con_dung) VALUES
  (1, 'Giá cao', 'Giá', TRUE),
  (2, 'Chọn nhà cung cấp khác', 'Đối thủ', TRUE),
  (3, 'Chưa có nhu cầu', 'Nhu cầu', TRUE),
  (4, 'Khác', 'Khác', TRUE);

-- ===== Lead =====
INSERT INTO lead (lead_id, source_id, ten_cong_ty, nguoi_lien_he, sdt, email, ghi_chu, assigned_to, ngay_tao, ngay_phan_bo, trang_thai, ly_do_khong_dat, account_id) VALUES
  (1, 1, 'Công ty Mẫu 01', 'Người liên hệ (mẫu)', '0900000001', NULL, NULL, 2, '2026-09-15 09:00:00', '2026-09-15 09:30:00', 'da_chuyen_deal', NULL, NULL),
  (2, 1, 'Công ty Mẫu 02', 'Người liên hệ (mẫu)', '0900000002', NULL, NULL, 2, '2026-09-22 09:00:00', '2026-09-22 09:30:00', 'da_chuyen_deal', NULL, NULL),
  (3, 2, 'Công ty Mẫu 03', 'Người liên hệ (mẫu)', '0900000003', NULL, NULL, 3, '2026-09-16 09:00:00', '2026-09-16 09:30:00', 'da_chuyen_deal', NULL, NULL),
  (4, 2, 'Công ty Mẫu 04', 'Người liên hệ (mẫu)', '0900000004', NULL, NULL, 3, '2026-09-29 09:00:00', '2026-09-29 09:30:00', 'da_chuyen_deal', NULL, NULL),
  (5, 1, 'Công ty Mẫu 05', 'Người liên hệ (mẫu)', '0900000005', NULL, NULL, 2, '2026-10-01 09:00:00', '2026-10-01 09:30:00', 'da_chuyen_deal', NULL, NULL),
  (6, 3, 'Công ty Mẫu 06', 'Người liên hệ (mẫu)', '0900000006', NULL, NULL, 3, '2026-10-08 09:00:00', '2026-10-08 09:30:00', 'da_chuyen_deal', NULL, NULL),
  (7, 1, 'Công ty Mẫu 07', 'Người liên hệ (mẫu)', '0900000007', NULL, NULL, 2, '2026-10-12 09:00:00', '2026-10-12 09:30:00', 'da_chuyen_deal', NULL, NULL),
  (8, 1, 'Lead mẫu 08', 'Người liên hệ (mẫu)', '0900000008', NULL, NULL, 2, '2026-09-24 09:00:00', '2026-09-24 09:30:00', 'khong_dat', 'khong_co_nhu_cau', NULL),
  (9, 1, 'Lead mẫu 09', 'Người liên hệ (mẫu)', '0900000009', NULL, NULL, 3, '2026-10-14 09:00:00', '2026-10-14 09:30:00', 'da_phan_bo', NULL, NULL),
  (10, 2, 'Lead mẫu 10', 'Người liên hệ (mẫu)', '0900000010', NULL, NULL, 2, '2026-09-30 09:00:00', '2026-09-30 09:30:00', 'khong_dat', 'khong_lien_lac_duoc', NULL),
  (11, 2, 'Lead mẫu 11', 'Người liên hệ (mẫu)', '0900000011', NULL, NULL, 3, '2026-10-21 09:00:00', '2026-10-21 09:30:00', 'da_phan_bo', NULL, NULL),
  (12, 3, 'Lead mẫu 12', 'Người liên hệ (mẫu)', '0900000012', NULL, NULL, 2, '2026-10-15 09:00:00', '2026-10-15 09:30:00', 'khong_dat', 'sai_thong_tin', NULL),
  (13, 1, 'Lead LA', 'Người liên hệ (mẫu)', '0900000013', NULL, NULL, 2, '2026-11-03 09:00:00', '2026-11-03 10:30:00', 'da_phan_bo', NULL, NULL),
  (14, 3, 'Lead LB', 'Người liên hệ (mẫu)', '0900000014', NULL, NULL, 3, '2026-10-30 20:00:00', '2026-11-02 09:30:00', 'da_phan_bo', NULL, NULL),
  (15, 2, 'Lead LC', 'Người liên hệ (mẫu)', '0900000015', NULL, NULL, 2, '2026-11-04 14:00:00', '2026-11-05 09:00:00', 'da_phan_bo', NULL, NULL),
  (16, 1, 'Lead LD', 'Người liên hệ (mẫu)', '0900000016', NULL, NULL, NULL, '2026-11-05 15:00:00', NULL, 'moi', NULL, NULL);

-- ===== Khách hàng (account) =====
INSERT INTO account (account_id, ten_thuong_goi, ten_chuan_hoa, ten_phap_ly, ma_so_thue, dia_chi_phap_ly, email_hoa_don, nganh, khu_vuc, source_id, owner_id, import_batch_id, ngay_tao, tao_boi, hoa_don_chuyen_luc, hoa_don_chuyen_boi) VALUES
  (1, 'Công ty Mẫu 01', 'công ty mẫu 01', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 1, 2, NULL, '2026-09-15 10:00:00', 2, NULL, NULL),
  (2, 'Công ty Mẫu 02', 'công ty mẫu 02', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 1, 2, NULL, '2026-09-22 10:00:00', 2, NULL, NULL),
  (3, 'Công ty Mẫu 03', 'công ty mẫu 03', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 2, 3, NULL, '2026-09-16 10:00:00', 3, NULL, NULL),
  (4, 'Công ty Mẫu 04', 'công ty mẫu 04', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 2, 3, NULL, '2026-09-29 10:00:00', 3, NULL, NULL),
  (5, 'Công ty Mẫu 05', 'công ty mẫu 05', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 1, 2, NULL, '2026-10-01 10:00:00', 2, NULL, NULL),
  (6, 'Công ty Mẫu 06', 'công ty mẫu 06', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 3, 3, NULL, '2026-10-08 10:00:00', 3, NULL, NULL),
  (7, 'Công ty Mẫu 07', 'công ty mẫu 07', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 1, 2, NULL, '2026-10-12 10:00:00', 2, NULL, NULL),
  (8, 'Công ty Mẫu 08', 'công ty mẫu 08', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 1, 2, NULL, '2026-10-08 09:00:00', 2, NULL, NULL),
  (9, 'Công ty Mẫu 09', 'công ty mẫu 09', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 2, 3, NULL, '2026-10-14 09:00:00', 3, NULL, NULL),
  (10, 'Công ty Mẫu 10', 'công ty mẫu 10', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 1, 3, NULL, '2026-10-01 09:00:00', 3, NULL, NULL),
  (11, 'Công ty Mẫu 11', 'công ty mẫu 11', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 2, 2, NULL, '2026-11-03 09:00:00', 2, NULL, NULL),
  (12, 'Công ty Mẫu 12', 'công ty mẫu 12', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 3, 2, NULL, '2026-10-06 09:00:00', 2, NULL, NULL),
  (13, 'Công ty Mẫu 13', 'công ty mẫu 13', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 1, 2, NULL, '2026-09-24 09:00:00', 2, NULL, NULL),
  (14, 'Công ty Mẫu 14', 'công ty mẫu 14', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 2, 3, NULL, '2026-10-01 09:00:00', 3, NULL, NULL),
  (15, 'Công ty Mẫu 15', 'công ty mẫu 15', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 1, 2, NULL, '2026-10-05 09:00:00', 2, NULL, NULL),
  (16, 'Công ty Mẫu 16', 'công ty mẫu 16', NULL, NULL, NULL, NULL, 'Dịch vụ', 'Hà Nội', 3, 3, NULL, '2026-10-12 09:00:00', 3, NULL, NULL);

UPDATE lead SET account_id = lead_id WHERE lead_id BETWEEN 1 AND 7;

-- ===== Deal (DK = đã ký 1-7, DT = thua 11-14, DM = đang mở 21-25) =====
INSERT INTO deal (deal_id, account_id, owner_id, source_id, lead_id, giai_doan, ngay_vao_giai_doan, gia_tri, goi_dich_vu, ngay_ky, ly_do_thua_id, ghi_chu_thua, ngay_tao) VALUES
  (1, 1, 2, 1, 1, 'da_ky', '2026-10-02 10:00:00', 120000000, NULL, '2026-10-02', NULL, NULL, '2026-09-15 10:00:00'),
  (2, 2, 2, 1, 2, 'da_ky', '2026-10-06 10:00:00', 80000000, NULL, '2026-10-06', NULL, NULL, '2026-09-22 10:00:00'),
  (3, 3, 3, 2, 3, 'da_ky', '2026-10-09 10:00:00', 200000000, NULL, '2026-10-09', NULL, NULL, '2026-09-16 10:00:00'),
  (4, 4, 3, 2, 4, 'da_ky', '2026-10-14 10:00:00', 150000000, NULL, '2026-10-14', NULL, NULL, '2026-09-29 10:00:00'),
  (5, 5, 2, 1, 5, 'da_ky', '2026-10-20 10:00:00', 90000000, NULL, '2026-10-20', NULL, NULL, '2026-10-01 10:00:00'),
  (6, 6, 3, 3, 6, 'da_ky', '2026-10-27 10:00:00', 60000000, NULL, '2026-10-27', NULL, NULL, '2026-10-08 10:00:00'),
  (7, 7, 2, 1, 7, 'da_ky', '2026-10-30 10:00:00', 100000000, NULL, '2026-10-30', NULL, NULL, '2026-10-12 10:00:00'),
  (11, 13, 2, 1, NULL, 'thua', '2026-10-08 10:00:00', 50000000, NULL, NULL, 1, NULL, '2026-09-24 09:00:00'),
  (12, 14, 3, 2, NULL, 'thua', '2026-10-15 10:00:00', NULL, NULL, NULL, 1, NULL, '2026-10-01 09:00:00'),
  (13, 15, 2, 1, NULL, 'thua', '2026-10-22 10:00:00', 70000000, NULL, NULL, 2, NULL, '2026-10-05 09:00:00'),
  (14, 16, 3, 3, NULL, 'thua', '2026-10-25 10:00:00', 30000000, NULL, NULL, 4, 'Khách tạm dừng kế hoạch', '2026-10-12 09:00:00'),
  (21, 8, 2, 1, NULL, 'tu_van', '2026-10-15 09:00:00', 40000000, NULL, NULL, NULL, NULL, '2026-10-08 09:00:00'),
  (22, 9, 3, 2, NULL, 'bao_gia', '2026-10-28 09:00:00', 75000000, NULL, NULL, NULL, NULL, '2026-10-14 09:00:00'),
  (23, 10, 3, 1, NULL, 'dam_phan', '2026-10-18 09:00:00', 110000000, NULL, NULL, NULL, NULL, '2026-10-01 09:00:00'),
  (24, 11, 2, 2, NULL, 'lien_he', '2026-11-03 09:00:00', NULL, NULL, NULL, NULL, NULL, '2026-11-03 09:00:00'),
  (25, 12, 2, 3, NULL, 'bao_gia', '2026-10-20 09:00:00', 55000000, NULL, NULL, NULL, NULL, '2026-10-06 09:00:00');

-- ===== Lịch sử đổi giai đoạn =====
INSERT INTO deal_stage_history (history_id, deal_id, tu_giai_doan, den_giai_doan, nguoi_doi, thoi_diem) VALUES
  (1, 1, NULL, 'lien_he', 2, '2026-09-15 10:00:00'),
  (2, 1, 'lien_he', 'tu_van', 2, '2026-09-18 10:00:00'),
  (3, 1, 'tu_van', 'bao_gia', 2, '2026-09-23 10:00:00'),
  (4, 1, 'bao_gia', 'dam_phan', 2, '2026-09-28 10:00:00'),
  (5, 1, 'dam_phan', 'da_ky', 2, '2026-10-02 10:00:00'),
  (6, 2, NULL, 'lien_he', 2, '2026-09-22 10:00:00'),
  (7, 2, 'lien_he', 'tu_van', 2, '2026-09-25 10:00:00'),
  (8, 2, 'tu_van', 'bao_gia', 2, '2026-09-30 10:00:00'),
  (9, 2, 'bao_gia', 'dam_phan', 2, '2026-10-02 10:00:00'),
  (10, 2, 'dam_phan', 'da_ky', 2, '2026-10-06 10:00:00'),
  (11, 3, NULL, 'lien_he', 3, '2026-09-16 10:00:00'),
  (12, 3, 'lien_he', 'tu_van', 3, '2026-09-21 10:00:00'),
  (13, 3, 'tu_van', 'bao_gia', 3, '2026-09-28 10:00:00'),
  (14, 3, 'bao_gia', 'dam_phan', 3, '2026-10-05 10:00:00'),
  (15, 3, 'dam_phan', 'da_ky', 3, '2026-10-09 10:00:00'),
  (16, 4, NULL, 'lien_he', 3, '2026-09-29 10:00:00'),
  (17, 4, 'lien_he', 'tu_van', 3, '2026-10-02 10:00:00'),
  (18, 4, 'tu_van', 'bao_gia', 3, '2026-10-06 10:00:00'),
  (19, 4, 'bao_gia', 'dam_phan', 3, '2026-10-09 10:00:00'),
  (20, 4, 'dam_phan', 'da_ky', 3, '2026-10-14 10:00:00'),
  (21, 5, NULL, 'lien_he', 2, '2026-10-01 10:00:00'),
  (22, 5, 'lien_he', 'tu_van', 2, '2026-10-05 10:00:00'),
  (23, 5, 'tu_van', 'bao_gia', 2, '2026-10-09 10:00:00'),
  (24, 5, 'bao_gia', 'dam_phan', 2, '2026-10-14 10:00:00'),
  (25, 5, 'dam_phan', 'da_ky', 2, '2026-10-20 10:00:00'),
  (26, 6, NULL, 'lien_he', 3, '2026-10-08 10:00:00'),
  (27, 6, 'lien_he', 'tu_van', 3, '2026-10-12 10:00:00'),
  (28, 6, 'tu_van', 'bao_gia', 3, '2026-10-16 10:00:00'),
  (29, 6, 'bao_gia', 'dam_phan', 3, '2026-10-21 10:00:00'),
  (30, 6, 'dam_phan', 'da_ky', 3, '2026-10-27 10:00:00'),
  (31, 7, NULL, 'lien_he', 2, '2026-10-12 10:00:00'),
  (32, 7, 'lien_he', 'tu_van', 2, '2026-10-15 10:00:00'),
  (33, 7, 'tu_van', 'bao_gia', 2, '2026-10-20 10:00:00'),
  (34, 7, 'bao_gia', 'dam_phan', 2, '2026-10-26 10:00:00'),
  (35, 7, 'dam_phan', 'da_ky', 2, '2026-10-30 10:00:00'),
  (36, 21, NULL, 'lien_he', 2, '2026-10-08 09:00:00'),
  (37, 21, 'lien_he', 'tu_van', 2, '2026-10-15 09:00:00'),
  (38, 22, NULL, 'lien_he', 3, '2026-10-14 09:00:00'),
  (39, 22, 'lien_he', 'tu_van', 3, '2026-10-21 09:00:00'),
  (40, 22, 'tu_van', 'bao_gia', 3, '2026-10-28 09:00:00'),
  (41, 23, NULL, 'lien_he', 3, '2026-10-01 09:00:00'),
  (42, 23, 'lien_he', 'tu_van', 3, '2026-10-06 09:00:00'),
  (43, 23, 'tu_van', 'bao_gia', 3, '2026-10-12 09:00:00'),
  (44, 23, 'bao_gia', 'dam_phan', 3, '2026-10-18 09:00:00'),
  (45, 24, NULL, 'lien_he', 2, '2026-11-03 09:00:00'),
  (46, 25, NULL, 'lien_he', 2, '2026-10-06 09:00:00'),
  (47, 25, 'lien_he', 'tu_van', 2, '2026-10-13 09:00:00'),
  (48, 25, 'tu_van', 'bao_gia', 2, '2026-10-20 09:00:00'),
  (49, 11, NULL, 'lien_he', 2, '2026-09-24 09:00:00'),
  (50, 11, 'lien_he', 'tu_van', 2, '2026-10-01 09:00:00'),
  (51, 11, 'tu_van', 'thua', 2, '2026-10-08 10:00:00'),
  (52, 12, NULL, 'lien_he', 3, '2026-10-01 09:00:00'),
  (53, 12, 'lien_he', 'bao_gia', 3, '2026-10-08 09:00:00'),
  (54, 12, 'bao_gia', 'thua', 3, '2026-10-15 10:00:00'),
  (55, 13, NULL, 'lien_he', 2, '2026-10-05 09:00:00'),
  (56, 13, 'lien_he', 'tu_van', 2, '2026-10-12 09:00:00'),
  (57, 13, 'tu_van', 'dam_phan', 2, '2026-10-17 09:00:00'),
  (58, 13, 'dam_phan', 'thua', 2, '2026-10-22 10:00:00'),
  (59, 14, NULL, 'lien_he', 3, '2026-10-12 09:00:00'),
  (60, 14, 'lien_he', 'thua', 3, '2026-10-25 10:00:00');

-- ===== Thanh toán (Kế toán xác nhận, user 7) =====
INSERT INTO payment (payment_id, deal_id, loai, so_tien, ngay_thu, xac_nhan_boi, xac_nhan_luc) VALUES
  (1, 1, 'coc', 60000000, '2026-10-05', 7, '2026-10-05 16:00:00'),
  (2, 2, 'coc', 40000000, '2026-10-20', 7, '2026-10-20 16:00:00'),
  (3, 2, 'tat_toan', 40000000, '2026-10-28', 7, '2026-10-28 16:00:00'),
  (4, 3, 'tat_toan', 200000000, '2026-10-12', 7, '2026-10-12 16:00:00'),
  (5, 5, 'coc', 45000000, '2026-11-03', 7, '2026-11-03 16:00:00'),
  (6, 6, 'coc', 30000000, '2026-10-30', 7, '2026-10-30 16:00:00');

-- ===== Bàn giao Cổng 2 (HA, HB, HC của T-28 mục 9.3) =====
INSERT INTO handoff (handoff_id, deal_id, cong, gui_boi, gui_luc, han_sla, xac_nhan_boi, xac_nhan_luc, tra_lai_boi, tra_lai_luc, ly_do_tra_lai, ghi_chu_tra_lai) VALUES
  (1, 1, 2, 2, '2026-10-30 15:00:00', '2026-11-02 10:00:00', 6, '2026-11-02 09:00:00', NULL, NULL, NULL, NULL),
  (2, 2, 2, 2, '2026-11-03 09:00:00', '2026-11-03 13:00:00', 6, '2026-11-03 14:30:00', NULL, NULL, NULL, NULL),
  (3, 3, 2, 3, '2026-11-04 16:00:00', '2026-11-05 11:00:00', NULL, NULL, NULL, NULL, NULL, NULL);
COMMIT;
