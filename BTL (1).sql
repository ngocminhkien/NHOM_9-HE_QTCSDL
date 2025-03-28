
-- Tạo mới CSDL
CREATE DATABASE QLthucpham;
USE QLthucpham;
GO

-- Tạo bảng Sản phẩm
CREATE TABLE SanPham (
    MaSP INT IDENTITY PRIMARY KEY,
    TenSP VARCHAR(255) NOT NULL,
    Gia DECIMAL(10, 2) NOT NULL CHECK (Gia > 0),
    SoLuong INT NOT NULL CHECK (SoLuong >= 0),
    NgayHetHan DATE
);
GO

-- Tạo bảng Khách hàng
CREATE TABLE KhachHang (
    MaKH INT IDENTITY PRIMARY KEY,
    TenKH VARCHAR(255) NOT NULL,
    Email VARCHAR(255) UNIQUE,
    SDT VARCHAR(15) UNIQUE
);
GO

-- Tạo bảng Đơn Hàng
CREATE TABLE DonHang (
    MaDH INT IDENTITY PRIMARY KEY,
    MaKH INT NOT NULL,
    NgayDat DATE DEFAULT GETDATE(),
    TongTien DECIMAL(10, 2) CHECK (TongTien >= 0),
    FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH) ON DELETE CASCADE
);
GO

-- Tạo bảng Chi Tiết Đơn Hàng
CREATE TABLE ChiTietDonHang (
    MaCTDH INT IDENTITY PRIMARY KEY,
    MaDH INT NOT NULL,
    MaSP INT NOT NULL,
    SoLuongMua INT NOT NULL CHECK (SoLuongMua > 0),
    FOREIGN KEY (MaDH) REFERENCES DonHang(MaDH) ON DELETE CASCADE,
    FOREIGN KEY (MaSP) REFERENCES SanPham(MaSP) ON DELETE CASCADE
);
GO

-- Tạo bảng Nhà Cung Cấp
CREATE TABLE Nhacc (
    Manhacc INT IDENTITY PRIMARY KEY,
    Tenncc VARCHAR(255) NOT NULL,
    Diachi VARCHAR(255),
    SDT VARCHAR(15) UNIQUE
);
GO

-- Tạo View danh sách sản phẩm
CREATE VIEW View_SanPham AS
SELECT MaSP, TenSP, Gia, SoLuong, NgayHetHan FROM SanPham;
GO

-- Tạo view danh sách khách hàng
CREATE VIEW View_KhachHang AS
SELECT MaKH, TenKH, Email, SDT FROM KhachHang;
GO


-- Tạo view danh sách đơn hàng
CREATE VIEW View_DonHang AS
SELECT MaDH, MaKH, NgayDat, TongTien FROM DonHang;
GO

-- Tạo view danh sách chi tiết đơn hàng
CREATE VIEW View_ChiTietDonHang AS
SELECT MaCTDH, MaDH, MaSP, SoLuongMua FROM ChiTietDonHang;
GO

-- Tạo Procedure Thêm Sản Phẩm
CREATE PROCEDURE ThemSanPham
    @TenSP NVARCHAR(255),
    @Gia DECIMAL(10,2),
    @SoLuong INT,
    @NgayHetHan DATE,
AS
BEGIN
    IF @Gia <= 0 OR @SoLuong < 0
    BEGIN
        PRINT N'Lỗi: Giá và số lượng phải lớn hơn 0!';
    END
    ELSE
    BEGIN
        INSERT INTO SanPham (TenSP, Gia, SoLuong, NgayHetHan, LoaiSP)
        VALUES (@TenSP, @Gia, @SoLuong, @NgayHetHan);
        PRINT N'Thêm sản phẩm thành công!';
    END
END;
GO
EXEC ThemSanPham @TenSP = N'Chuối hỗn hợp', @Gia = 230000, @SoLuong = 20, @NgayHetHan = '2024-10-10';
GO

--Tạo Procedure xóa sản phẩm
CREATE PROCEDURE XoaSanPham
    @MaSP INT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM SanPham WHERE MaSP = @MaSP)
    BEGIN
        -- Xóa sản phẩm khỏi các đơn hàng trước (nếu có)
        DELETE FROM ChiTietDonHang WHERE MaSP = @MaSP;
        DELETE FROM SanPham WHERE MaSP = @MaSP;
        PRINT N'Xóa sản phẩm thành công!';
    END
    ELSE
    BEGIN
        PRINT N'Lỗi: Không tìm thấy sản phẩm!';
    END
END;
GO
EXEC XoaSanPham @MaSP = 1;
GO


--Xóa đơn hàng
CREATE PROCEDURE XoaDonHang
    @MaDH INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Kiểm tra đơn hàng có tồn tại không
    IF NOT EXISTS (SELECT 1 FROM DonHang WHERE MaDH = @MaDH)
    BEGIN
        PRINT N'Lỗi: Không tìm thấy đơn hàng!';
        RETURN;
    END;

    -- Xóa đơn hàng (trigger sẽ tự động xóa ChiTietDonHang)
    DELETE FROM DonHang WHERE MaDH = @MaDH;

    PRINT N'Xóa đơn hàng thành công!';
END;
GO

EXEC XoaDonHang @MaDH = 1;
GO


-CREATE TRIGGER trg_UpdateSoLuong
ON ChiTietDonHang
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Kiểm tra số lượng sản phẩm có đủ để trừ hay không
        IF EXISTS (
            SELECT 1
            FROM inserted i
            JOIN SanPham s ON i.MaSP = s.MaSP
            WHERE s.SoLuong < i.SoLuongMua
        )
        BEGIN
            RAISERROR (N'Lỗi: Không đủ số lượng sản phẩm trong kho!', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Cập nhật số lượng sản phẩm sau khi mua
        UPDATE SanPham
        SET SoLuong = s.SoLuong - i.SoLuongMua
        FROM SanPham s
        INNER JOIN inserted i ON s.MaSP = i.MaSP;
    END TRY
    BEGIN CATCH
        -- Bắt lỗi và hiển thị thông báo lỗi
        PRINT N'Lỗi khi cập nhật số lượng sản phẩm: ' + ERROR_MESSAGE();
        ROLLBACK TRANSACTION;
    END CATCH;
END;
GO

-- Kiểm tra những tài khoản đã tồn tại
SELECT name FROM sys.database_principals WHERE type IN ('S', 'U');

-- Kiểm tra login đã tồn tại chưa
SELECT name FROM sys.server_principals WHERE type IN ('S', 'U', 'G');

-- Kiểm tra người đã tồn tại trong database chưa
SELECT name FROM sys.database_principals WHERE type = 'U';

-- Xóa user nếu tồn tại
USE QLthucpham;
GO
DROP USER IF EXISTS QUANLYUSER;
DROP USER IF EXISTS NHANVIENUSER;
DROP USER IF EXISTS KHACHHANGUSER;
GO

-- Xóa login nếu tồn tại
USE QLthucpham;
GO
-- Kiểm tra và xóa login nếu tồn tại
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'QUANLY')
BEGIN
    DROP LOGIN QUANLY;
END;
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'NHANVIEN')
BEGIN
    DROP LOGIN NHANVIEN;
END;
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'KHACHHANG')
BEGIN
    DROP LOGIN KHACHHANG;
END;
GO

-- Tạo login mới với mật khẩu mạnh
CREATE LOGIN QUANLY WITH PASSWORD = 'Ql@123456', CHECK_POLICY = OFF;
CREATE LOGIN NHANVIEN WITH PASSWORD = 'Nv@123456', CHECK_POLICY = OFF;
CREATE LOGIN KHACHHANG WITH PASSWORD = 'Kh@123456', CHECK_POLICY = OFF;
GO

-- Tạo user mới trong database
CREATE USER QUANLYUSER FOR LOGIN QUANLY;
CREATE USER NHANVIENUSER FOR LOGIN NHANVIEN;
CREATE USER KHACHHANGUSER FOR LOGIN KHACHHANG;
GO

-- Cấp quyền truy cập database
ALTER ROLE db_owner ADD MEMBER QUANLYUSER;
GRANT CONNECT TO QUANLYUSER;

ALTER ROLE db_datareader ADD MEMBER NHANVIENUSER;
GRANT CONNECT TO NHANVIENUSER;

ALTER ROLE db_datareader ADD MEMBER KHACHHANGUSER;
GRANT CONNECT TO KHACHHANGUSER;
GO

-- Phân quyền đúng user
GRANT SELECT, INSERT, UPDATE, DELETE ON SanPham TO QUANLYUSER;
GRANT SELECT ON SanPham TO NHANVIENUSER;
GRANT SELECT ON View_SanPham TO KHACHHANGUSER;
GO


-- Thêm dữ liệu vào bảng Sản phẩm
INSERT INTO SanPham (TenSP, Gia, SoLuong, NgayHetHan)
VALUES 
    ('Sữa tươi Vinamilk', 25000, 100, '2025-12-31'),
    ('Bánh mì Sandwich', 15000, 50, '2024-06-30'),
    ('Thịt bò Úc', 320000, 30, '2024-07-15'),
    ('Táo Mỹ', 85000, 80, '2024-08-01'),
    ('Gạo ST25', 180000, 200, '2025-01-01');
GO

-- Thêm dữ liệu vào bảng Khách hàng
INSERT INTO KhachHang (TenKH, Email, SDT)
VALUES 
    ('Nguyễn Văn A', 'nguyenvana@example.com', '0987654321'),
    ('Trần Thị B', 'tranthib@example.com', '0901234567'),
    ('Lê Văn C', 'levanc@example.com', '0934567890');
GO

-- Thêm dữ liệu vào bảng Đơn hàng
INSERT INTO DonHang (MaKH, NgayDat, TongTien)
VALUES 
    (1, '2024-03-15', 350000),
    (2, '2024-03-16', 120000),
    (3, '2024-03-17', 450000);
GO

-- Thêm dữ liệu vào bảng Chi Tiết Đơn Hàng
INSERT INTO ChiTietDonHang (MaDH, MaSP, SoLuongMua)
VALUES 
    (1, 1, 2),  -- Đơn hàng 1 mua 2 hộp sữa Vinamilk
    (1, 3, 1),  -- Đơn hàng 1 mua 1kg thịt bò Úc
    (2, 2, 3),  -- Đơn hàng 2 mua 3 bánh mì Sandwich
    (3, 5, 1);  -- Đơn hàng 3 mua 1 túi gạo ST25
GO

-- Thêm dữ liệu vào bảng Nhà cung cấp
INSERT INTO Nhacc (Tenncc, Diachi, SDT)
VALUES 
    ('Công ty Vinamilk', 'Tp. Hồ Chí Minh', '02812345678'),
    ('Bánh mì ABC', 'Hà Nội', '02498765432'),
    ('Nhà phân phối thịt bò Úc', 'Đà Nẵng', '0511223344');
GO

USE QLthucpham;
GO
SELECT
    dp.name AS UserName,
    drm.name AS RoleName
FROM sys.database_principals dp
JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
JOIN sys.database_principals dr ON drm.role_principal_id = dr.principal_id
WHERE dp.type = 'S' OR dp.type = 'U'
ORDER BY dp.name;
GO

USE QLthucpham;
GO

SELECT
    dp.name AS UserName,
    p.permission_name AS PermissionName,
    o.name AS ObjectName
FROM sys.database_permissions p
JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
LEFT JOIN sys.objects o ON p.major_id = o.object_id
WHERE dp.type = 'S' OR dp.type = 'U'
ORDER BY dp.name, p.permission_name;
GO

USE QLthucpham;
GO

SELECT name
FROM sys.database_principals
WHERE type = 'R';
GO