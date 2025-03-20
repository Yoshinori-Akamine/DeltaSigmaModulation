----------------------------------------------------------------------------------
-- Company: Myway Plus Corporation 
-- Module Name: pwm_if
-- Target Devices: Kintex-7 xc7k70t
-- Tool Versions: Vivado 2016.4
-- Create Date: 2025/03/09
-- Revision: 1.0
-- Side note: This is for the DSM test
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library unisim;
use unisim.vcomponents.all;

entity pwm_if is
    port (
        CLK_IN           : in std_logic;
        RESET_IN        : in std_logic;
        nPWM_UP_OUT    : out std_logic; --nUSER_OPT_OUT(0)
        nPWM_UN_OUT    : out std_logic; --nUSER_OPT_OUT(1)
        nPWM_VP_OUT    : out std_logic; --nUSER_OPT_OUT(2)
        nPWM_VN_OUT    : out std_logic; --nUSER_OPT_OUT(3)
        nPWM_WP_OUT    : out std_logic; --nUSER_OPT_OUT(4)
        nPWM_WN_OUT    : out std_logic; --nUSER_OPT_OUT(5)
        nUSER_OPT_OUT : out std_logic_vector (23 downto 6);

        UPDATE    : in std_logic;
        CARRIER   : in std_logic_vector (15 downto 0);
        U_REF    : in std_logic_vector (15 downto 0);
        V_REF    : in std_logic_vector (15 downto 0);
        W_REF    : in std_logic_vector (15 downto 0);
        DEADTIME : in std_logic_vector (12 downto 0);
        GATE_EN  : in std_logic;

        --my costom
        Duty : in std_logic_vector(15 downto 0)
    );
end pwm_if;

architecture Behavioral of pwm_if is

    component deadtime_if is
        Port (
            CLK_IN     : in std_logic;
            RESET_IN : in std_logic;
            DT           : in std_logic_vector(12 downto 0);
            G_IN        : in std_logic;
            G_OUT      : out std_logic
        );
    end component;

    component DeltaSigma_PDM is
        port (
        CLK_IN      : in  std_logic;                -- クロック入力
        RESET_IN    : in  std_logic;                -- リセット入力
        FULL_IN_1   : in  std_logic;                -- フルパルス入力(例)1 (スイッチ1)
        FULL_IN_2   : in  std_logic;                -- フルパルス入力(例)2
        FULL_IN_3   : in  std_logic;                -- フルパルス入力(例)3
        FULL_IN_4   : in  std_logic;                -- フルパルス入力(例)4
        DUTY_IN     : in  std_logic_vector(15 downto 0);  -- (0～1000)の整数Duty
        PDM_OUT_1   : out std_logic;               -- PDM出力(例)1
        PDM_OUT_2   : out std_logic;               -- PDM出力(例)2
        PDM_OUT_3   : out std_logic;               -- PDM出力(例)3
        PDM_OUT_4   : out std_logic                -- PDM出力(例)4
        );
    end component;

    signal carrier_cnt_max_b : std_logic_vector (15 downto 0);
    signal carrier_cnt_max_bb : std_logic_vector (15 downto 0);
    signal carrier_cnt       : std_logic_vector (15 downto 0);
    signal carrier_up_down : std_logic;
    signal u_ref_b : std_logic_vector (15 downto 0);
    signal v_ref_b : std_logic_vector (15 downto 0);
    signal w_ref_b : std_logic_vector (15 downto 0);
    signal u_ref_bb : std_logic_vector (15 downto 0);
    signal v_ref_bb : std_logic_vector (15 downto 0);
    signal w_ref_bb : std_logic_vector (15 downto 0);
    signal pwm_up : std_logic;
    signal pwm_un : std_logic;
    signal pwm_vp : std_logic;
    signal pwm_vn : std_logic;
    signal pwm_wp : std_logic;
    signal pwm_wn : std_logic;
    signal pwm_up_dt : std_logic := '0';
    signal pwm_un_dt : std_logic := '0';
    signal pwm_vp_dt : std_logic := '0';
    signal pwm_vn_dt : std_logic := '0';
    signal pwm_wp_dt : std_logic := '0';
    signal pwm_wn_dt : std_logic := '0';
    signal dt_b : std_logic_vector (12 downto 0);
    signal dt_bb : std_logic_vector (12 downto 0);
    signal gate_en_b : std_logic := '0';

    -- my costom
    signal inv_signal : std_logic;
    signal pwm_up_dsm : std_logic := '0';
    signal pwm_un_dsm : std_logic := '0';
    signal pwm_vp_dsm : std_logic := '0';
    signal pwm_vn_dsm : std_logic := '0';

    -- my attribute
    attribute mark_debug : string;
    attribute mark_debug of carrier_cnt_max_b : signal is "true";
    attribute mark_debug of carrier_cnt : signal is "true";  -- something is wrong
    attribute mark_debug of pwm_up : signal is "true";
    attribute mark_debug of pwm_un : signal is "true";
    attribute mark_debug of pwm_vp : signal is "true";
    attribute mark_debug of pwm_vn : signal is "true";
    attribute mark_debug of pwm_up_dt : signal is "true";
    attribute mark_debug of pwm_un_dt : signal is "true";
    attribute mark_debug of pwm_vp_dt : signal is "true";
    attribute mark_debug of pwm_vn_dt : signal is "true";
    --attribute mark_debug of inv_signal : signal is "true";
    attribute mark_debug of pwm_up_dsm : signal is "true";
    attribute mark_debug of pwm_un_dsm : signal is "true";
    attribute mark_debug of pwm_vp_dsm : signal is "true";
    attribute mark_debug of pwm_vn_dsm : signal is "true";



begin

    process(CLK_IN)
    begin
        if CLK_IN'event and CLK_IN = '1' then
            if RESET_IN = '1' then
                gate_en_b <= '0';
            else
                gate_en_b <= GATE_EN;
            end if;

            if RESET_IN = '1' then
                carrier_cnt_max_b  <= X"1388"; -- 10kHz
                carrier_cnt        <= X"0000";
                u_ref_b <= X"09C4"; -- m = 0.5
                v_ref_b <= X"09C4"; -- m = 0.5
                w_ref_b <= X"09C4"; -- m = 0.5
                dt_b <= '0' & X"190"; -- 4us
            elsif UPDATE = '1' then
                carrier_cnt_max_b <= CARRIER;
                u_ref_b <= U_REF;
                v_ref_b <= V_REF;
                w_ref_b <= W_REF;
                dt_b <= DEADTIME;
            end if;       

            if RESET_IN = '1' then
                carrier_up_down <= '1';
                carrier_cnt_max_bb <= X"1388";
            elsif carrier_cnt = X"0001" and carrier_up_down = '0' then
                carrier_up_down <= '1';
            elsif carrier_cnt >= (carrier_cnt_max_bb -1) and carrier_up_down = '1' then
                carrier_up_down <= '0';
                carrier_cnt_max_bb <= carrier_cnt_max_b;
            end if;

            if RESET_IN = '1' then
                carrier_cnt <= X"0000";
            elsif carrier_up_down = '1' then
                carrier_cnt <= carrier_cnt + 1;
            else
                carrier_cnt <= carrier_cnt - 1;
            end if;   

        end if;
    end process;

    process(CLK_IN)
    begin
        if CLK_IN'event and CLK_IN = '1' then
            if RESET_IN = '1' then
                u_ref_bb <= X"09C4"; -- m = 0.5
                v_ref_bb <= X"09C4"; -- m = 0.5
                w_ref_bb <= X"09C4"; -- m = 0.5
            elsif carrier_cnt = (carrier_cnt_max_bb -1) and carrier_up_down = '1' then
                u_ref_bb <= u_ref_b;
                v_ref_bb <= v_ref_b;
                w_ref_bb <= w_ref_b;
            end if;

            if RESET_IN = '1' then
                pwm_up <= '0';
                pwm_un <= '1';
                pwm_vp <= '0';
                pwm_vn <= '1';
                pwm_wp <= '0';
                pwm_wn <= '0';
            elsif carrier_cnt >= u_ref_bb then
                pwm_up <= '0';
                pwm_un <= '1';
                pwm_vp <= '1';
                pwm_vn <= '0';
                pwm_wp <= '0';
                pwm_wn <= '0';
            else
                pwm_up <= '1';
                pwm_un <= '0';
                pwm_vp <= '0';
                pwm_vn <= '1';
                pwm_wp <= '0';
                pwm_wn <= '0';
            end if;
        end if;
    end process;

    process(CLK_IN)
    begin
        if CLK_IN'event and CLK_IN = '1' then
            if RESET_IN = '1' then
                dt_bb <= '0' & X"190"; -- 4us
            elsif carrier_cnt = (carrier_cnt_max_bb -1) then
                dt_bb <= dt_b;
            end if;
        end if;
    end process;
    
        -- my costom (not end)
    delta_sigma_modulation : DeltaSigma_PDM port map (
        CLK_IN   => CLK_IN,
        RESET_IN => RESET_IN,
        FULL_IN_1 => pwm_up,
        FULL_IN_2 => pwm_un,
        FULL_IN_3 => pwm_vp,
        FULL_IN_4 => pwm_vn,
        DUTY_IN  => Duty,
        PDM_OUT_1 => pwm_up_dsm,
        PDM_OUT_2 => pwm_un_dsm,
        PDM_OUT_3 => pwm_vp_dsm,
        PDM_OUT_4 => pwm_vn_dsm
    );

    dt_up : deadtime_if port map (CLK_IN => CLK_IN, RESET_IN => RESET_IN, DT => dt_bb, G_IN => pwm_up_dsm, G_OUT => pwm_up_dt);
    dt_un : deadtime_if port map (CLK_IN => CLK_IN, RESET_IN => RESET_IN, DT => dt_bb, G_IN => pwm_un_dsm, G_OUT => pwm_un_dt);
    dt_vp : deadtime_if port map (CLK_IN => CLK_IN, RESET_IN => RESET_IN, DT => dt_bb, G_IN => pwm_vp_dsm, G_OUT => pwm_vp_dt);
    dt_vn : deadtime_if port map (CLK_IN => CLK_IN, RESET_IN => RESET_IN, DT => dt_bb, G_IN => pwm_vn_dsm, G_OUT => pwm_vn_dt);
    dt_wp : deadtime_if port map (CLK_IN => CLK_IN, RESET_IN => RESET_IN, DT => dt_bb, G_IN => pwm_wp, G_OUT => pwm_wp_dt);
    dt_wn : deadtime_if port map (CLK_IN => CLK_IN, RESET_IN => RESET_IN, DT => dt_bb, G_IN => pwm_wn, G_OUT => pwm_wn_dt);


    nPWM_UP_OUT <= not (pwm_up_dt and gate_en_b);
    nPWM_UN_OUT <= not (pwm_un_dt and gate_en_b);
    nPWM_VP_OUT <= not (pwm_vp_dt and gate_en_b);
    nPWM_VN_OUT <= not (pwm_vn_dt and gate_en_b);
    nPWM_WP_OUT <= not (pwm_wp_dt and gate_en_b);
    nPWM_WN_OUT <= not (pwm_wn_dt and gate_en_b);

    nUSER_OPT_OUT(6) <= not (pwm_up_dt and gate_en_b);
    nUSER_OPT_OUT(7) <= not (pwm_un_dt and gate_en_b);
    nUSER_OPT_OUT(8) <= not (pwm_vp_dt and gate_en_b);
    nUSER_OPT_OUT(9) <= not (pwm_vn_dt and gate_en_b);
    nUSER_OPT_OUT(10) <= not (pwm_wp_dt and gate_en_b);
    nUSER_OPT_OUT(11) <= not (pwm_wn_dt and gate_en_b);
    nUSER_OPT_OUT(12) <= not (pwm_up_dt and gate_en_b);
    nUSER_OPT_OUT(13) <= not (pwm_un_dt and gate_en_b);
    nUSER_OPT_OUT(14) <= not (pwm_vp_dt and gate_en_b);
    nUSER_OPT_OUT(15) <= not (pwm_vn_dt and gate_en_b);
    nUSER_OPT_OUT(16) <= not (pwm_wp_dt and gate_en_b);
    nUSER_OPT_OUT(17) <= not (pwm_wn_dt and gate_en_b);
    nUSER_OPT_OUT(18) <= not (pwm_up_dt and gate_en_b);
    nUSER_OPT_OUT(19) <= not (pwm_un_dt and gate_en_b);
    nUSER_OPT_OUT(20) <= not (pwm_vp_dt and gate_en_b);
    nUSER_OPT_OUT(21) <= not (pwm_vn_dt and gate_en_b);
    nUSER_OPT_OUT(22) <= not (pwm_wp_dt and gate_en_b);
    nUSER_OPT_OUT(23) <= not (pwm_wn_dt and gate_en_b);

end Behavioral;


----------------------------------------------------------------------------------
--Deadtime module
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library unisim;
use unisim.vcomponents.all;

entity deadtime_if is
    Port (
        CLK_IN     : in std_logic;
        RESET_IN : in std_logic;
        DT           : in std_logic_vector(12 downto 0);
        G_IN        : in std_logic;
        G_OUT      : out std_logic
        );
end deadtime_if;

architecture behavioral of deadtime_if is
signal d_g_in: std_logic;
signal cnt: std_logic_vector(12 downto 0);
signal gate: std_logic;

begin

    process(CLK_IN)
    begin
        if (CLK_IN'event and CLK_IN='1') then
            if RESET_IN = '1' then
                d_g_in <= '0';
            else
                d_g_in <= G_IN;
            end if;

            if RESET_IN = '1' then
                cnt   <= "0000000000001";
                gate <= '0';
            elsif (d_g_in = '0' and G_IN = '1') then
                cnt   <= "0000000000001";
                gate <= '0';
            elsif (cnt >= DT) then
                cnt   <= "1111111111111";
                gate <= d_g_in;
            elsif (cnt /= "1111111111111") then
                cnt   <= cnt + 1;
                gate <= '0';
            else
                gate <= d_g_in;
            end if;
        end if;
    end process;

    G_OUT <= gate;

end behavioral;


----------------------------------------------------------------------------------
-- Module Name: DeltaSigma_PDM
-- Target Devices: Kintex-7 xc7k70t
-- Tool Versions: Vivado 2016.4
-- Create Date: 2025/02/18
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- 本サンプルでは、Dutyおよびaccをすべて 0～1000 で扱う。
-- 1000を"1.0"相当として、負の値になり得ないアルゴリズムにする。
-- ホストからは 0～1000 の整数Dutyが入ってくる前提。
--
-- 今回の追加要件:
--   inv_output = '1' のとき -> 遅延した各FULL_IN_xをそのまま出力(PDM的動作)
--   inv_output = '0' のとき -> ショートモード
--     * スイッチ2と4 ON
--     * スイッチ1と3はOFF
-------------------------------------------------------------------------------

entity DeltaSigma_PDM is
    port (
        CLK_IN      : in  std_logic;                -- クロック入力
        RESET_IN    : in  std_logic;                -- リセット入力
        FULL_IN_1   : in  std_logic;                -- フルパルス入力(例)1 (スイッチ1)
        FULL_IN_2   : in  std_logic;                -- フルパルス入力(例)2
        FULL_IN_3   : in  std_logic;                -- フルパルス入力(例)3
        FULL_IN_4   : in  std_logic;                -- フルパルス入力(例)4
        DUTY_IN     : in  std_logic_vector(15 downto 0);  -- (0～1000)の整数Duty
        PDM_OUT_1   : out std_logic;               -- PDM出力(例)1
        PDM_OUT_2   : out std_logic;               -- PDM出力(例)2
        PDM_OUT_3   : out std_logic;               -- PDM出力(例)3
        PDM_OUT_4   : out std_logic                -- PDM出力(例)4
    );
end DeltaSigma_PDM;

architecture Behavioral of DeltaSigma_PDM is

    -----------------------------------------------------------------------------
    -- 累積用レジスタ: acc
    -- 0～1000を想定。 1000を超えたら出力を1にして、1000引いて再度 0～999に戻す
    -----------------------------------------------------------------------------
    signal acc : unsigned(15 downto 0) := (others => '0');

    -----------------------------------------------------------------------------
    -- スイッチ変化で出力を決めるフラグ
    -----------------------------------------------------------------------------
    signal inv_output : std_logic := '0';

    -----------------------------------------------------------------------------
    -- 入力パルス(スイッチ1)の前回値
    -----------------------------------------------------------------------------
    signal in1_d       : std_logic := '0';  -- 前回値でエッジ検出に使う
    signal in1_delayed : std_logic := '0';  -- FULL_IN_1を1クロック遅らせた信号

    -- スイッチ2～4 も同様に遅延用信号を用意
    signal in2_delayed : std_logic := '0';
    signal in3_delayed : std_logic := '0';
    signal in4_delayed : std_logic := '0';
    
    attribute mark_debug : string;
    attribute mark_debug of acc : signal is "true";
    attribute mark_debug of inv_output : signal is "true";
    attribute mark_debug of in1_delayed : signal is "true";

begin
    -----------------------------------------------------------------------------
    -- メイン処理
    -- スイッチ1が変化したタイミングでDSMを駆動し、出力フラグ(inv_output)を決める
    -----------------------------------------------------------------------------
    process(CLK_IN)
        variable new_acc : unsigned(15 downto 0);
    begin
        if rising_edge(CLK_IN) then
            if RESET_IN = '1' then
                ----------------------------------------------------------
                -- リセット時の初期化
                ----------------------------------------------------------
                acc          <= (others => '0');
                inv_output   <= '0';
                in1_d        <= '0';
                in1_delayed  <= '0';
                in2_delayed  <= '0';
                in3_delayed  <= '0';
                in4_delayed  <= '0';
            else
                ----------------------------------------------------------
                -- 各 FULL_IN_x を1クロック遅らせる
                ----------------------------------------------------------
                in1_delayed <= FULL_IN_1;
                in2_delayed <= FULL_IN_2;
                in3_delayed <= FULL_IN_3;
                in4_delayed <= FULL_IN_4;

                ----------------------------------------------------------
                -- スイッチ1の立ち上がり/立ち下がり 検出
                ----------------------------------------------------------
                in1_d <= FULL_IN_1;
                if (FULL_IN_1 /= in1_d) then
                    ------------------------------------------------------
                    -- スイッチ1が変化した瞬間だけアルゴリズム更新
                    ------------------------------------------------------

                    new_acc := acc + unsigned(DUTY_IN);

                    if (new_acc >= to_unsigned(1000, 16)) then
                        inv_output <= '1';
                        new_acc := new_acc - to_unsigned(1000, 16);
                    else
                        inv_output <= '0';
                    end if;
                    acc <= new_acc;
                end if;

            end if;  -- RESET_IN
        end if;      -- rising_edge
    end process;

    -----------------------------------------------------------------------------
    -- 出力部:
    --   inv_output='1' => 1クロック遅らせたFULL_IN_x
    --   inv_output='0' => ショートモード(スイッチ2と4 ON, 1と3 OFF)
    -----------------------------------------------------------------------------

    PDM_OUT_1 <= in1_delayed when inv_output='1' else '0';
    PDM_OUT_2 <= in2_delayed when inv_output='1' else '1';
    PDM_OUT_3 <= in3_delayed when inv_output='1' else '0';
    PDM_OUT_4 <= in4_delayed when inv_output='1' else '1';

end Behavioral;


