-- LinkFlow CRM - T-29: SQL báo cáo trên dữ liệu mẫu (PostgreSQL 12 trở lên)
-- Chạy sau "Sprint 4_T29 Du lieu mau.sql". Ngày và giờ trong truy vấn là tham số mẫu; đổi khi cần. Thời điểm xem báo cáo: 2026-11-06 09:30 (thứ Sáu). Kỳ M = tháng 10/2026.
-- Giờ làm việc: 08:00-17:00, thứ Hai đến thứ Sáu, không trừ lễ và nghỉ trưa (SRS Phụ lục B.1, A-13).

-- Đưa mốc thời gian về giờ làm việc gần nhất kể từ t trở đi
CREATE OR REPLACE FUNCTION wh_next(t timestamp) RETURNS timestamp LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  LOOP
    IF EXTRACT(DOW FROM t) IN (0,6) OR t::time >= TIME '17:00' THEN
      t := date_trunc('day', t) + INTERVAL '1 day 8 hours';
    ELSIF t::time < TIME '08:00' THEN
      t := date_trunc('day', t) + INTERVAL '8 hours';
    ELSE
      RETURN t;
    END IF;
  END LOOP;
END $$;

-- WH(a, b): số giờ làm việc từ a đến b
CREATE OR REPLACE FUNCTION wh(a timestamp, b timestamp) RETURNS numeric LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE cur timestamp := wh_next(a); eod timestamp; total numeric := 0;
BEGIN
  IF a IS NULL OR b IS NULL THEN RETURN NULL; END IF;   -- tránh AVG bị kéo xuống khi lead chưa phân bổ
  WHILE cur < b LOOP
    eod := date_trunc('day', cur) + INTERVAL '17 hours';
    total := total + EXTRACT(EPOCH FROM (LEAST(eod, b) - cur)) / 3600.0;
    cur := wh_next(eod);
  END LOOP;
  RETURN round(total, 2);
END $$;

-- Hạn(t, n): thời điểm sau n giờ làm việc kể từ t
CREATE OR REPLACE FUNCTION han(t timestamp, n numeric) RETURNS timestamp LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE cur timestamp := wh_next(t); rem numeric := n; eod timestamp; avail numeric;
BEGIN
  LOOP
    eod := date_trunc('day', cur) + INTERVAL '17 hours';
    avail := EXTRACT(EPOCH FROM (eod - cur)) / 3600.0;
    IF rem <= avail THEN RETURN cur + rem * INTERVAL '1 hour'; END IF;
    rem := rem - avail; cur := wh_next(eod);
  END LOOP;
END $$;

-- DS-01 Số hợp đồng và giá trị, mốc Đã ký, kỳ M
SELECT 'DS-01' AS chi_so, COUNT(*) AS so_hd, SUM(gia_tri)/1e6 AS trieu FROM deal
WHERE giai_doan='da_ky' AND ngay_ky >= '2026-10-01' AND ngay_ky < '2026-11-01';

-- DS-02 mốc Đã cọc (ngày mốc = ngày thu sớm nhất)
SELECT 'DS-02', COUNT(*), SUM(d.gia_tri)/1e6 FROM deal d
JOIN (SELECT deal_id, MIN(ngay_thu) AS ngay_coc FROM payment GROUP BY deal_id) p USING (deal_id)
WHERE d.giai_doan='da_ky' AND p.ngay_coc >= '2026-10-01' AND p.ngay_coc < '2026-11-01';

-- DS-03 Tiền đã thu trong kỳ
SELECT 'DS-03', SUM(so_tien)/1e6 FROM payment WHERE ngay_thu >= '2026-10-01' AND ngay_thu < '2026-11-01';

-- DS-04 Đã ký chưa thu (tuổi tính đến thời điểm xem, quá hạn khi tuổi > 7 ngày)
-- Tuổi = ngày xem − ngày ký, tính theo ngày lịch (bỏ phần giờ): trừ hai kiểu DATE trong PostgreSQL cho ra số nguyên
SELECT 'DS-04' AS chi_so, deal_id, gia_tri/1e6 AS trieu,
       (DATE '2026-11-06' - ngay_ky) AS tuoi_ngay,
       (DATE '2026-11-06' - ngay_ky) > 7 AS qua_han
FROM deal d WHERE giai_doan='da_ky' AND ngay_ky >= '2026-10-01' AND ngay_ky < '2026-11-01'
  AND NOT EXISTS (SELECT 1 FROM payment p WHERE p.deal_id=d.deal_id AND p.ngay_thu <= '2026-11-06');

-- PL-01 Pipeline đang mở
SELECT 'PL-01', giai_doan, COUNT(*) AS so_deal, SUM(gia_tri)/1e6 AS trieu, COUNT(*) FILTER (WHERE gia_tri IS NULL) AS thieu_gia_tri
FROM deal WHERE giai_doan IN ('lien_he','tu_van','bao_gia','dam_phan') GROUP BY giai_doan ORDER BY 2;

-- PL-02 Deal kẹt (đứng yên quá 14 ngày ở một giai đoạn mở)
SELECT 'PL-02' AS chi_so, deal_id, giai_doan,
       (DATE '2026-11-06' - ngay_vao_giai_doan::date) AS ngay_o_giai_doan,
       gia_tri/1e6 AS trieu
FROM deal WHERE giai_doan IN ('lien_he','tu_van','bao_gia','dam_phan')
  AND (DATE '2026-11-06' - ngay_vao_giai_doan::date) > 14 ORDER BY 4 DESC;

-- PL-05 Tỷ lệ thắng = ký / (ký + thua) trong kỳ; ngày thua lấy từ lịch sử giai đoạn (A-39)
SELECT 'PL-05' AS chi_so, k.so_ky, t.so_thua, round(100.0*k.so_ky/(k.so_ky+t.so_thua),1) AS ty_le_thang
FROM (SELECT COUNT(*) AS so_ky FROM deal WHERE giai_doan='da_ky' AND ngay_ky >= '2026-10-01' AND ngay_ky < '2026-11-01') k,
     (SELECT COUNT(DISTINCT deal_id) AS so_thua FROM deal_stage_history
      WHERE den_giai_doan='thua' AND thoi_diem >= '2026-10-01' AND thoi_diem < '2026-11-01') t;

-- NG-02 Chuyển đổi theo nguồn, lead tạo từ 01/09 đến hết 31/10
SELECT 'NG-02' AS chi_so, s.kenh, COUNT(*) AS so_lead,
       COUNT(*) FILTER (WHERE l.trang_thai='da_chuyen_deal') AS len_deal,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM deal d WHERE d.lead_id=l.lead_id AND d.giai_doan='da_ky')) AS len_ky,
       round(100.0*COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM deal d WHERE d.lead_id=l.lead_id AND d.giai_doan='da_ky'))/COUNT(*),1) AS ty_le_ky
FROM lead l JOIN source_campaign s USING (source_id)
WHERE l.ngay_tao >= '2026-09-01' AND l.ngay_tao < '2026-11-01' GROUP BY s.kenh ORDER BY 3 DESC;

-- NG-03 Giá trị ký theo nguồn, kỳ M
SELECT 'NG-03' AS chi_so, s.kenh, COUNT(*) AS so_hd, SUM(d.gia_tri)/1e6 AS trieu,
       round(100.0*SUM(d.gia_tri)/SUM(SUM(d.gia_tri)) OVER (),1) AS ty_trong
FROM deal d JOIN source_campaign s USING (source_id)
WHERE d.giai_doan='da_ky' AND d.ngay_ky >= '2026-10-01' AND d.ngay_ky < '2026-11-01' GROUP BY s.kenh ORDER BY 4 DESC;

-- LM-01 Lý do thua trong kỳ
SELECT 'LM-01' AS chi_so, r.ten_ly_do, COUNT(*) AS so_deal, SUM(COALESCE(d.gia_tri,0))/1e6 AS trieu, COUNT(*) FILTER (WHERE d.gia_tri IS NULL) AS thieu_gia_tri
FROM deal d JOIN lost_reason r USING (ly_do_thua_id)
WHERE d.giai_doan='thua' GROUP BY r.ten_ly_do ORDER BY 3 DESC;

-- LD-01 Lead chờ phân bổ (tại thời điểm xem)
SELECT 'LD-01' AS chi_so, lead_id, ngay_tao, han(ngay_tao, 2) AS han_phan_bo,
       wh(ngay_tao, TIMESTAMP '2026-11-06 09:30') AS gio_lam_viec_cho,
       TIMESTAMP '2026-11-06 09:30' > han(ngay_tao, 2) AS qua_han
FROM lead WHERE trang_thai='moi';

-- LD-02 Lead đúng hạn phân bổ: cohort lead tạo từ 30/10 đến 05/11 (LB, LA, LC, LD)
SELECT 'LD-02' AS chi_so, lead_id, ngay_tao, han(ngay_tao, 2) AS han, ngay_phan_bo,
       wh(ngay_tao, ngay_phan_bo) AS gio_lam_viec_phan_bo,
       CASE WHEN ngay_phan_bo IS NULL THEN 'chua phan bo, da qua han' WHEN ngay_phan_bo <= han(ngay_tao,2) THEN 'dung han' ELSE 'tre' END AS ket_qua
FROM lead WHERE ngay_tao >= '2026-10-30' AND ngay_tao < '2026-11-06' ORDER BY ngay_tao;

-- BG-01 Thời gian xác nhận bàn giao Cổng 2 (SLA 4 giờ làm việc)
SELECT 'BG-01' AS chi_so, handoff_id, deal_id, gui_luc, han_sla, xac_nhan_luc,
       wh(gui_luc, xac_nhan_luc) AS gio_lam_viec, xac_nhan_luc <= han_sla AS dung_sla
FROM handoff WHERE cong=2 AND xac_nhan_luc IS NOT NULL ORDER BY handoff_id;

-- BG-02 Form chờ nhận và quá hạn
SELECT 'BG-02' AS chi_so, handoff_id, deal_id, han_sla,
       wh(han_sla, TIMESTAMP '2026-11-06 09:30') AS gio_lam_viec_qua_han
FROM handoff WHERE cong=2 AND xac_nhan_luc IS NULL AND tra_lai_luc IS NULL AND han_sla < TIMESTAMP '2026-11-06 09:30';

-- BG-03 Hợp đồng đã ký (kỳ M) chưa có form bàn giao
SELECT 'BG-03' AS chi_so, d.deal_id, (DATE '2026-11-06' - d.ngay_ky) AS tuoi_ngay, (DATE '2026-11-06' - d.ngay_ky) > 2 AS cham_gui
FROM deal d WHERE d.giai_doan='da_ky' AND d.ngay_ky >= '2026-10-01' AND d.ngay_ky < '2026-11-01'
  AND NOT EXISTS (SELECT 1 FROM handoff h WHERE h.deal_id=d.deal_id AND h.cong=2) ORDER BY 2;

-- ===================== Gộp số liệu (tổng hợp từ các truy vấn chi tiết ở trên) =====================

-- PL-02 gộp: số deal kẹt, giá trị kẹt, tỷ lệ kẹt trên deal mở
SELECT 'PL-02 gop' AS chi_so, COUNT(*) FILTER (WHERE (DATE '2026-11-06' - ngay_vao_giai_doan::date) > 14) AS so_ket,
       SUM(COALESCE(gia_tri,0)) FILTER (WHERE (DATE '2026-11-06' - ngay_vao_giai_doan::date) > 14)/1e6 AS trieu_ket,
       COUNT(*) AS so_mo,
       round(100.0 * COUNT(*) FILTER (WHERE (DATE '2026-11-06' - ngay_vao_giai_doan::date) > 14) / COUNT(*), 1) AS ty_le_ket_pct
FROM deal WHERE giai_doan IN ('lien_he','tu_van','bao_gia','dam_phan');

-- LD-02 gộp: tỷ lệ đúng hạn và thời gian phân bổ trung bình (giờ làm việc)
WITH x AS (SELECT lead_id, ngay_tao, ngay_phan_bo, han(ngay_tao, 2) AS han FROM lead WHERE ngay_tao >= '2026-10-30' AND ngay_tao < '2026-11-06')
SELECT 'LD-02 gop' AS chi_so,
       COUNT(*) FILTER (WHERE ngay_phan_bo IS NOT NULL OR TIMESTAMP '2026-11-06 09:30' > han) AS den_han,
       COUNT(*) FILTER (WHERE ngay_phan_bo <= han) AS dung_han,
       round(100.0 * COUNT(*) FILTER (WHERE ngay_phan_bo <= han) / COUNT(*) FILTER (WHERE ngay_phan_bo IS NOT NULL OR TIMESTAMP '2026-11-06 09:30' > han), 1) AS ty_le_pct,
       round(AVG(wh(ngay_tao, ngay_phan_bo)), 1) AS gio_lam_viec_tb
FROM x;

-- BG-01 gộp: tỷ lệ đúng SLA và thời gian xác nhận trung bình (chỉ tính form đã xác nhận)
SELECT 'BG-01 gop' AS chi_so, COUNT(*) AS so_form, COUNT(*) FILTER (WHERE xac_nhan_luc <= han_sla) AS dung_sla,
       round(100.0 * COUNT(*) FILTER (WHERE xac_nhan_luc <= han_sla) / COUNT(*), 1) AS ty_le_pct,
       round(AVG(wh(gui_luc, xac_nhan_luc)), 1) AS gio_lam_viec_tb
FROM handoff WHERE cong = 2 AND xac_nhan_luc IS NOT NULL;

-- ===================== Chỉ số Should còn lại =====================

-- PL-06 Phễu chuyển giai đoạn: deal tạo từ 01/09 đến hết 31/10; R(k) = số deal đã đạt giai đoạn thứ k trở lên (bỏ qua 'thua')
WITH thu_tu AS (SELECT * FROM (VALUES ('lien_he',1),('tu_van',2),('bao_gia',3),('dam_phan',4),('da_ky',5)) v(giai_doan, k)),
cao_nhat AS (
  SELECT d.deal_id, COALESCE(MAX(t.k), 1) AS k_max
  FROM deal d LEFT JOIN deal_stage_history h ON h.deal_id = d.deal_id
  LEFT JOIN thu_tu t ON t.giai_doan = h.den_giai_doan
  WHERE d.ngay_tao >= '2026-09-01' AND d.ngay_tao < '2026-11-01' GROUP BY d.deal_id),
r AS (SELECT k, (SELECT COUNT(*) FROM cao_nhat c WHERE c.k_max >= t.k) AS so_deal, giai_doan FROM thu_tu t)
SELECT 'PL-06' AS chi_so, a.giai_doan AS tu, b.giai_doan AS den, a.so_deal AS r_tu, b.so_deal AS r_den,
       round(100.0 * b.so_deal / NULLIF(a.so_deal, 0), 1) AS ty_le_pct
FROM r a JOIN r b ON b.k = a.k + 1 ORDER BY a.k;

-- PL-03 Thời gian trung bình ở mỗi giai đoạn (ngày lịch), theo thời điểm rời giai đoạn trong tháng 10
WITH ls AS (
  SELECT deal_id, den_giai_doan AS giai_doan, thoi_diem AS vao,
         LEAD(thoi_diem) OVER (PARTITION BY deal_id ORDER BY thoi_diem, history_id) AS roi
  FROM deal_stage_history)
SELECT 'PL-03' AS chi_so, giai_doan, COUNT(*) AS so_lan, round(AVG(roi::date - vao::date), 1) AS ngay_tb
FROM ls WHERE roi IS NOT NULL AND giai_doan NOT IN ('da_ky','thua') AND roi >= '2026-10-01' AND roi < '2026-11-01'
GROUP BY giai_doan ORDER BY MIN(vao);

-- LM-02 Tỷ lệ lý do "Khác" trong các deal thua của tháng 10 (ngày thua lấy từ lịch sử giai đoạn)
SELECT 'LM-02' AS chi_so,
       COUNT(*) FILTER (WHERE r.ten_ly_do = 'Khác') AS so_khac, COUNT(*) AS tong_thua,
       round(100.0 * COUNT(*) FILTER (WHERE r.ten_ly_do = 'Khác') / COUNT(*), 1) AS ty_le_pct
FROM deal d JOIN lost_reason r USING (ly_do_thua_id)
JOIN (SELECT deal_id, MIN(thoi_diem) AS ngay_thua FROM deal_stage_history WHERE den_giai_doan='thua' GROUP BY deal_id) h USING (deal_id)
WHERE d.giai_doan = 'thua' AND h.ngay_thua >= '2026-10-01' AND h.ngay_thua < '2026-11-01';

-- DQ-01 Bảng kiểm chất lượng dữ liệu (tại thời điểm xem)
SELECT 'DQ-a deal da ky thieu gia tri' AS kiem_tra, COUNT(*) FILTER (WHERE gia_tri IS NULL) AS so_loi, COUNT(*) AS tong FROM deal WHERE giai_doan='da_ky'
UNION ALL SELECT 'DQ-b deal mo va thua thieu gia tri', COUNT(*) FILTER (WHERE gia_tri IS NULL), COUNT(*) FROM deal WHERE giai_doan <> 'da_ky'
UNION ALL SELECT 'DQ-c deal nguon chua xac dinh', COUNT(*) FILTER (WHERE s.kenh='Chưa xác định'), COUNT(*) FROM deal d JOIN source_campaign s USING (source_id)
UNION ALL SELECT 'DQ-c lead nguon chua xac dinh', COUNT(*) FILTER (WHERE s.kenh='Chưa xác định'), COUNT(*) FROM lead l JOIN source_campaign s USING (source_id)
UNION ALL SELECT 'DQ-d deal mo do nguoi da nghi phu trach', COUNT(*) FILTER (WHERE NOT u.dang_hoat_dong), COUNT(*) FROM deal d JOIN users u ON u.user_id = d.owner_id WHERE d.giai_doan IN ('lien_he','tu_van','bao_gia','dam_phan');

-- ===================== Viết lại 5 truy vấn của T-04 mục 11 theo ERD v0.4 và PostgreSQL =====================

-- Câu 1 (cũ: lead chưa phân bổ quá 24 giờ lịch). Mới: lead chờ quá 2 giờ làm việc (BR-02), tại thời điểm xem
SELECT l.lead_id, l.ngay_tao, han(l.ngay_tao, 2) AS han_phan_bo, wh(l.ngay_tao, TIMESTAMP '2026-11-06 09:30') AS gio_lam_viec_cho
FROM lead l WHERE l.assigned_to IS NULL AND TIMESTAMP '2026-11-06 09:30' > han(l.ngay_tao, 2);

-- Câu 2 (cũ: dùng payment.trang_thai không tồn tại). Mới: đã ký quá 7 ngày, chưa có khoản thu nào (cọc hoặc tất toán thẳng, BR-09)
SELECT d.deal_id, a.ten_thuong_goi, d.ngay_ky, (DATE '2026-11-06' - d.ngay_ky) AS tuoi_ngay
FROM deal d JOIN account a USING (account_id)
WHERE d.giai_doan = 'da_ky' AND (DATE '2026-11-06' - d.ngay_ky) > 7
  AND NOT EXISTS (SELECT 1 FROM payment p WHERE p.deal_id = d.deal_id AND p.ngay_thu <= DATE '2026-11-06');

-- Câu 3 (cũ: giờ lịch, gộp cả Cổng 3). Mới: chỉ Cổng 2, tính giờ làm việc
SELECT round(AVG(wh(gui_luc, xac_nhan_luc)), 1) AS gio_lam_viec_tb, COUNT(*) AS so_form
FROM handoff WHERE cong = 2 AND xac_nhan_luc IS NOT NULL;

-- Câu 4 (cũ: lead.trang_thai = 'da_ky', giá trị này không tồn tại). Mới: dùng deal.lead_id (CR-01)
SELECT s.kenh, COUNT(*) AS so_lead,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM deal d WHERE d.lead_id = l.lead_id AND d.giai_doan = 'da_ky')) AS so_ky,
       round(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM deal d WHERE d.lead_id = l.lead_id AND d.giai_doan = 'da_ky')) / COUNT(*), 1) AS ty_le_pct
FROM lead l JOIN source_campaign s USING (source_id)
WHERE l.ngay_tao >= '2026-09-01' AND l.ngay_tao < '2026-11-01' GROUP BY s.kenh ORDER BY ty_le_pct DESC;

-- Câu 5 (giữ ý, thêm xử lý thiếu giá trị): lý do mất hợp đồng nhiều nhất và giá trị mất
SELECT r.ten_ly_do, COUNT(*) AS so_deal_thua, SUM(COALESCE(d.gia_tri, 0)) AS gia_tri_mat, COUNT(*) FILTER (WHERE d.gia_tri IS NULL) AS thieu_gia_tri
FROM deal d JOIN lost_reason r USING (ly_do_thua_id) WHERE d.giai_doan = 'thua'
GROUP BY r.ten_ly_do ORDER BY so_deal_thua DESC;
