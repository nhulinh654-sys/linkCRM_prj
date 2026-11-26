-- LinkFlow CRM - T-29: thử các ràng buộc của T-13 v0.4 (mỗi lệnh phải bị từ chối, trừ hai ràng buộc do ứng dụng đảm bảo)
\set ON_ERROR_STOP off
-- P1: deal Đã ký thiếu ngày ký -> bị CHECK từ chối
INSERT INTO deal (deal_id,account_id,owner_id,source_id,giai_doan,ngay_vao_giai_doan,ngay_tao) VALUES (99,1,2,1,'da_ky','2026-11-01 10:00','2026-11-01 10:00');
-- P2: deal Thua thiếu lý do -> bị CHECK từ chối
INSERT INTO deal (deal_id,account_id,owner_id,source_id,giai_doan,ngay_vao_giai_doan,ngay_tao) VALUES (98,1,2,1,'thua','2026-11-01 10:00','2026-11-01 10:00');
-- P3: khoản thu thứ hai cùng loại cho một deal -> bị UNIQUE từ chối
INSERT INTO payment VALUES (90,1,'coc',1,'2026-11-02',7,'2026-11-02 10:00');
-- P4: form Cổng 2 thứ hai đang hiệu lực cho deal 3 -> bị UNIQUE một phần từ chối
INSERT INTO handoff (handoff_id,deal_id,cong,gui_boi,gui_luc) VALUES (90,3,2,3,'2026-11-05 10:00');
-- P4b: gửi lại sau khi bị trả lại vẫn hợp lệ: đánh dấu form cũ đã trả lại rồi thêm form mới
BEGIN;
UPDATE handoff SET tra_lai_luc='2026-11-05 12:00', tra_lai_boi=6, ly_do_tra_lai='thieu_thong_tin' WHERE handoff_id=3;
INSERT INTO handoff (handoff_id,deal_id,cong,gui_boi,gui_luc) VALUES (91,3,2,3,'2026-11-05 15:00');
ROLLBACK;
-- P5, P6: không có ràng buộc ở cơ sở dữ liệu, các lệnh này được nhận (ứng dụng phải đảm bảo)
BEGIN;
UPDATE lead SET trang_thai='da_chuyen_deal' WHERE lead_id=9;
UPDATE deal SET source_id=3 WHERE deal_id=1;
SELECT 'P5 lead da_chuyen_deal khong co deal' AS kiem_tra, COUNT(*) FROM lead l WHERE trang_thai='da_chuyen_deal' AND NOT EXISTS (SELECT 1 FROM deal d WHERE d.lead_id=l.lead_id)
UNION ALL SELECT 'P6 deal lech nguon voi lead', COUNT(*) FROM deal d JOIN lead l USING(lead_id) WHERE d.source_id<>l.source_id;
ROLLBACK;
