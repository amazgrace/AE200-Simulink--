% =========================================================================
% AE200 起落架系统 (LGS) Simulink 2021b 初始化脚本
% 包含：总线定义、初始状态、全局物理常数
% =========================================================================
clear; clc;

%% 1. 定义外部输入总线 (Input Bus)
% 1.1 航电/控制指令总线
elem(1) = Simulink.BusElement; elem(1).Name = 'Brake_Cmd'; elem(1).Dimensions = 1; elem(1).DataType = 'double'; % 刹车指令
elem(2) = Simulink.BusElement; elem(2).Name = 'Steer_Cmd'; elem(2).Dimensions = 1; elem(2).DataType = 'double'; % 转弯指令
elem(3) = Simulink.BusElement; elem(3).Name = 'Channel_Select'; elem(3).Dimensions = 1; elem(3).DataType = 'boolean'; % 0为主, 1为备
elem(4) = Simulink.BusElement; elem(4).Name = 'BIT_Trigger'; elem(4).Dimensions = 1; elem(4).DataType = 'uint8'; % 1:PBIT, 2:CBIT, 3:MBIT
Bus_Avionics_In = Simulink.Bus; Bus_Avionics_In.Elements = elem; clear elem;

% 1.2 飞机六自由度状态总线
% ================= 1. 质心位置 (Position - 通常为地面坐标系/NED) =================
elem(1) = Simulink.BusElement; elem(1).Name = 'X_Position'; elem(1).Dimensions = 1; elem(1).DataType = 'double'; % X坐标 (计算滑跑距离)
elem(2) = Simulink.BusElement; elem(2).Name = 'Y_Position'; elem(2).Dimensions = 1; elem(2).DataType = 'double'; % Y坐标 (计算侧偏轨迹)
elem(3) = Simulink.BusElement; elem(3).Name = 'Z_Position'; elem(3).Dimensions = 1; elem(3).DataType = 'double'; % Z坐标 (高度，决定是否接地)

% ================= 2. 质心线速度 (Velocity - 通常为机体坐标系 Body Frame) =================
elem(4) = Simulink.BusElement; elem(4).Name = 'U_Velocity'; elem(4).Dimensions = 1; elem(4).DataType = 'double'; % 纵向速度 (算轮胎纵向滑移率 k 必备)
elem(5) = Simulink.BusElement; elem(5).Name = 'V_Velocity'; elem(5).Dimensions = 1; elem(5).DataType = 'double'; % 侧向速度 (算轮胎侧滑角 Beta 必备)
elem(6) = Simulink.BusElement; elem(6).Name = 'W_Velocity'; elem(6).Dimensions = 1; elem(6).DataType = 'double'; % 垂向速度 (算缓冲器压缩速度必备)

% ================= 3. 姿态角 (Euler Angles) =================
elem(7) = Simulink.BusElement; elem(7).Name = 'Roll_Angle';  elem(7).Dimensions = 1; elem(7).DataType = 'double'; % 滚转角 Phi (决定左右主起落架谁先接地，以及受力分配)
elem(8) = Simulink.BusElement; elem(8).Name = 'Pitch_Angle'; elem(8).Dimensions = 1; elem(8).DataType = 'double'; % 俯仰角 Theta (决定前起和主起的载荷分配，防机尾擦地)
elem(9) = Simulink.BusElement; elem(9).Name = 'Yaw_Angle';   elem(9).Dimensions = 1; elem(9).DataType = 'double'; % 偏航角 Psi (地面滑跑方向)

% ================= 4. 机体角速度 (Angular Rates - Body Frame) =================
elem(10) = Simulink.BusElement; elem(10).Name = 'Roll_Rate';  elem(10).Dimensions = 1; elem(10).DataType = 'double'; % 滚转角速度 p
elem(11) = Simulink.BusElement; elem(11).Name = 'Pitch_Rate'; elem(11).Dimensions = 1; elem(11).DataType = 'double'; % 俯仰角速度 q
elem(12) = Simulink.BusElement; elem(12).Name = 'Yaw_Rate';   elem(12).Dimensions = 1; elem(12).DataType = 'double'; % 偏航角速度 r (前轮转向、侧风滑跑时，yaw rate极大地影响各机轮的横向线速度)
Bus_Aircraft_State = Simulink.Bus; Bus_Aircraft_State.Elements = elem; clear elem;

% 1.3 供电与环境总线
elem(1) = Simulink.BusElement; elem(1).Name = 'Vdc_1'; elem(1).Dimensions = 1; elem(1).DataType = 'double'; % 主供电
elem(2) = Simulink.BusElement; elem(2).Name = 'Vdc_2'; elem(2).Dimensions = 1; elem(2).DataType = 'double'; % 备供电
elem(3) = Simulink.BusElement; elem(3).Name = 'Mu_Ground'; elem(3).Dimensions = 1; elem(3).DataType = 'double'; % 地面摩擦系数
elem(4) = Simulink.BusElement; elem(4).Name = 'Theta_Runway'; elem(4).Dimensions = 1; elem(4).DataType = 'double'; % 跑道坡度
Bus_Env_Power = Simulink.Bus; Bus_Env_Power.Elements = elem; clear elem;

%% 2. 定义外部输出总线 (Output Bus)
% 2.1 状态与反馈总线
elem(1) = Simulink.BusElement; elem(1).Name = 'WOW_Nose'; elem(1).Dimensions = 1; elem(1).DataType = 'boolean';
elem(2) = Simulink.BusElement; elem(2).Name = 'WOW_LeftMain'; elem(2).Dimensions = 1; elem(2).DataType = 'boolean';
elem(3) = Simulink.BusElement; elem(3).Name = 'WOW_RightMain'; elem(3).Dimensions = 1; elem(3).DataType = 'boolean';
elem(4) = Simulink.BusElement; elem(4).Name = 'Brake_Pressure_FB'; elem(4).Dimensions = 1; elem(4).DataType = 'double';
elem(5) = Simulink.BusElement; elem(5).Name = 'Fault_Status_Word'; elem(5).Dimensions = 1; elem(5).DataType = 'uint16'; % 故障状态字
Bus_LGS_Feedback = Simulink.Bus; Bus_LGS_Feedback.Elements = elem; clear elem;

% 2.2 动力学受力总线 (输出给六自由度)
elem(1) = Simulink.BusElement; elem(1).Name = 'Force_XYZ'; elem(1).Dimensions = 3; elem(1).DataType = 'double';
elem(2) = Simulink.BusElement; elem(2).Name = 'Moment_XYZ'; elem(2).Dimensions = 3; elem(2).DataType = 'double';
Bus_LGS_Dynamics = Simulink.Bus; Bus_LGS_Dynamics.Elements = elem; clear elem;

%% 3. 初始化全局参数
P_LGS.Vdc_Norm = 28.0;     % 正常供电电压
P_LGS.Vdc_Degrade = 22.0;  % 降级电压阈值
P_LGS.Vdc_Fail = 18.0;     % 失效电压阈值
P_LGS.Hyd_Max = 21.0;      % 最大系统压力 (MPa)

disp('LGS 总线与基础参数初始化完成。请运行 Simulink 模型。');