#!/usr/bin/env python3
"""
Whisper模型性能测试脚本
功能：测试不同Whisper模型的识别效果、速度和资源消耗
"""

import os
import sys
import time
import json
import subprocess
import tempfile
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
import psutil
import threading

@dataclass
class ModelResult:
    """模型测试结果"""
    model_name: str
    text: str
    duration: float  # 识别耗时(秒)
    file_size: int   # 音频文件大小(字节)
    cpu_usage: float # CPU使用率
    memory_usage: float # 内存使用量(MB)
    success: bool
    error: str = ""

class WhisperBenchmark:
    """Whisper模型基准测试工具"""
    
    # Whisper可用模型列表
    AVAILABLE_MODELS = [
        "tiny",     # 最小模型，速度最快，准确率较低
        "base",     # 基础模型，平衡速度和准确率
        "small",    # 小型模型，较好的准确率
        "medium",   # 中型模型，更好的准确率
        "large",    # 大型模型，最佳准确率，但速度较慢
        "large-v2", # 大型模型v2版本
        "large-v3", # 大型模型v3版本(最新)
    ]
    
    def __init__(self, test_audio_file: str = None, language: str = "Chinese"):
        self.test_audio_file = test_audio_file
        self.language = language
        self.results: List[ModelResult] = []
        self.temp_dir = tempfile.mkdtemp(prefix="whisper_test_")
        
    def check_dependencies(self) -> bool:
        """检查依赖工具"""
        try:
            result = subprocess.run(["whisper", "--help"], 
                                  capture_output=True, text=True)
            if result.returncode != 0:
                print("❌ Whisper未安装或不可用")
                return False
            print("✅ Whisper可用")
            return True
        except FileNotFoundError:
            print("❌ 未找到whisper命令，请先安装 openai-whisper")
            return False
    
    def record_test_audio(self, duration: int = 10) -> str:
        """录制测试音频"""
        print(f"📹 开始录制 {duration} 秒测试音频...")
        
        audio_file = os.path.join(self.temp_dir, "test_audio.wav")
        
        # 使用ffmpeg录制音频
        cmd = [
            "ffmpeg", "-y", "-loglevel", "error",
            "-f", "pulse", "-i", "default",
            "-ac", "1", "-ar", "16000",
            "-t", str(duration),
            audio_file
        ]
        
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            print(f"✅ 录制完成: {audio_file}")
            return audio_file
        except subprocess.CalledProcessError as e:
            print(f"❌ 录制失败: {e}")
            return None
    
    def monitor_resources(self, pid: int, results: Dict) -> None:
        """监控进程资源使用"""
        try:
            process = psutil.Process(pid)
            cpu_usage = []
            memory_usage = []
            
            while process.is_running():
                try:
                    cpu_usage.append(process.cpu_percent())
                    memory_usage.append(process.memory_info().rss / 1024 / 1024)  # MB
                    time.sleep(0.1)
                except psutil.NoSuchProcess:
                    break
            
            results['cpu_usage'] = sum(cpu_usage) / len(cpu_usage) if cpu_usage else 0
            results['memory_usage'] = max(memory_usage) if memory_usage else 0
            
        except Exception as e:
            print(f"⚠️ 资源监控失败: {e}")
            results['cpu_usage'] = 0
            results['memory_usage'] = 0
    
    def test_model(self, model_name: str, audio_file: str) -> ModelResult:
        """测试单个模型"""
        print(f"🧪 测试模型: {model_name}")
        
        # 获取音频文件大小
        file_size = os.path.getsize(audio_file)
        
        # 输出文件路径
        output_file = os.path.join(self.temp_dir, f"{model_name}_output.txt")
        
        # 构建whisper命令
        cmd = [
            "whisper", audio_file,
            "--model", model_name,
            "--language", self.language,
            "--output_format", "txt",
            "--output_dir", self.temp_dir,
            "--verbose", "False"
        ]
        
        # 监控资源使用
        monitor_results = {}
        
        start_time = time.time()
        try:
            # 启动whisper进程
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, 
                                     stderr=subprocess.PIPE, text=True)
            
            # 启动资源监控线程
            monitor_thread = threading.Thread(
                target=self.monitor_resources,
                args=(process.pid, monitor_results)
            )
            monitor_thread.start()
            
            # 等待进程完成
            stdout, stderr = process.communicate()
            duration = time.time() - start_time
            
            # 等待监控线程完成
            monitor_thread.join()
            
            if process.returncode == 0:
                # 读取识别结果
                audio_basename = Path(audio_file).stem
                result_file = os.path.join(self.temp_dir, f"{audio_basename}.txt")
                
                try:
                    with open(result_file, 'r', encoding='utf-8') as f:
                        text = f.read().strip()
                except FileNotFoundError:
                    text = "未找到输出文件"
                
                return ModelResult(
                    model_name=model_name,
                    text=text,
                    duration=duration,
                    file_size=file_size,
                    cpu_usage=monitor_results.get('cpu_usage', 0),
                    memory_usage=monitor_results.get('memory_usage', 0),
                    success=True
                )
            else:
                return ModelResult(
                    model_name=model_name,
                    text="",
                    duration=duration,
                    file_size=file_size,
                    cpu_usage=monitor_results.get('cpu_usage', 0),
                    memory_usage=monitor_results.get('memory_usage', 0),
                    success=False,
                    error=stderr.strip()
                )
                
        except Exception as e:
            duration = time.time() - start_time
            return ModelResult(
                model_name=model_name,
                text="",
                duration=duration,
                file_size=file_size,
                cpu_usage=0,
                memory_usage=0,
                success=False,
                error=str(e)
            )
    
    def run_benchmark(self, models: List[str] = None, 
                     record_audio: bool = False, 
                     audio_duration: int = 10) -> List[ModelResult]:
        """运行基准测试"""
        
        if not self.check_dependencies():
            return []
        
        # 确定要测试的模型
        if models is None:
            models = self.AVAILABLE_MODELS
        
        # 确定测试音频文件
        if record_audio or self.test_audio_file is None:
            self.test_audio_file = self.record_test_audio(audio_duration)
            if not self.test_audio_file:
                return []
        
        if not os.path.exists(self.test_audio_file):
            print(f"❌ 音频文件不存在: {self.test_audio_file}")
            return []
        
        print(f"🎵 使用音频文件: {self.test_audio_file}")
        print(f"📊 开始测试 {len(models)} 个模型...")
        
        # 测试每个模型
        self.results = []
        for i, model in enumerate(models, 1):
            print(f"\n[{i}/{len(models)}] " + "="*50)
            result = self.test_model(model, self.test_audio_file)
            self.results.append(result)
            
            if result.success:
                print(f"✅ {model}: {result.duration:.2f}s, CPU: {result.cpu_usage:.1f}%, 内存: {result.memory_usage:.1f}MB")
                print(f"   识别结果: {result.text[:100]}...")
            else:
                print(f"❌ {model}: 失败 - {result.error}")
        
        return self.results
    
    def generate_report(self, output_file: str = "whisper_benchmark_report.json") -> None:
        """生成测试报告"""
        if not self.results:
            print("❌ 没有测试结果可生成报告")
            return
        
        # 生成统计信息
        successful_results = [r for r in self.results if r.success]
        
        if not successful_results:
            print("❌ 没有成功的测试结果")
            return
        
        # 找出最佳性能模型
        fastest_model = min(successful_results, key=lambda x: x.duration)
        lowest_cpu = min(successful_results, key=lambda x: x.cpu_usage)
        lowest_memory = min(successful_results, key=lambda x: x.memory_usage)
        
        # 生成报告数据
        report = {
            "test_info": {
                "audio_file": self.test_audio_file,
                "language": self.language,
                "test_time": time.strftime("%Y-%m-%d %H:%M:%S"),
                "total_models": len(self.results),
                "successful_models": len(successful_results)
            },
            "summary": {
                "fastest_model": fastest_model.model_name,
                "fastest_time": fastest_model.duration,
                "lowest_cpu_model": lowest_cpu.model_name,
                "lowest_cpu_usage": lowest_cpu.cpu_usage,
                "lowest_memory_model": lowest_memory.model_name,
                "lowest_memory_usage": lowest_memory.memory_usage
            },
            "detailed_results": [asdict(result) for result in self.results]
        }
        
        # 保存报告
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        
        print(f"\n📄 测试报告已保存: {output_file}")
        
        # 打印简要报告
        self.print_summary()
    
    def print_summary(self) -> None:
        """打印测试总结"""
        if not self.results:
            return
        
        successful_results = [r for r in self.results if r.success]
        
        print("\n" + "="*60)
        print("📊 Whisper模型性能测试总结")
        print("="*60)
        
        if not successful_results:
            print("❌ 所有模型测试都失败了")
            return
        
        # 表格头
        print(f"{'模型':<12} {'耗时(s)':<8} {'CPU(%)':<8} {'内存(MB)':<10} {'状态':<6}")
        print("-" * 60)
        
        # 打印每个模型的结果
        for result in self.results:
            status = "✅" if result.success else "❌"
            print(f"{result.model_name:<12} {result.duration:<8.2f} "
                  f"{result.cpu_usage:<8.1f} {result.memory_usage:<10.1f} {status:<6}")
        
        # 推荐
        fastest = min(successful_results, key=lambda x: x.duration)
        lowest_resource = min(successful_results, key=lambda x: x.cpu_usage + x.memory_usage/100)
        
        print("\n🏆 推荐:")
        print(f"   最快速度: {fastest.model_name} ({fastest.duration:.2f}s)")
        print(f"   最低资源: {lowest_resource.model_name} (CPU: {lowest_resource.cpu_usage:.1f}%, 内存: {lowest_resource.memory_usage:.1f}MB)")
        
        # 显示识别文本对比
        print(f"\n📝 识别结果对比:")
        for result in successful_results:
            print(f"   {result.model_name}: {result.text[:80]}...")
    
    def cleanup(self) -> None:
        """清理临时文件"""
        import shutil
        if os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir)

def main():
    parser = argparse.ArgumentParser(description="Whisper模型性能测试工具")
    parser.add_argument("--audio", "-a", help="指定测试音频文件")
    parser.add_argument("--models", "-m", nargs="+", 
                       choices=WhisperBenchmark.AVAILABLE_MODELS,
                       help="指定要测试的模型")
    parser.add_argument("--record", "-r", action="store_true",
                       help="录制新的测试音频")
    parser.add_argument("--duration", "-d", type=int, default=10,
                       help="录制音频时长(秒)")
    parser.add_argument("--language", "-l", default="Chinese",
                       help="识别语言")
    parser.add_argument("--output", "-o", default="whisper_benchmark_report.json",
                       help="报告输出文件")
    
    args = parser.parse_args()
    
    # 创建测试实例
    benchmark = WhisperBenchmark(
        test_audio_file=args.audio,
        language=args.language
    )
    
    try:
        # 运行测试
        results = benchmark.run_benchmark(
            models=args.models,
            record_audio=args.record,
            audio_duration=args.duration
        )
        
        if results:
            # 生成报告
            benchmark.generate_report(args.output)
        else:
            print("❌ 测试失败，无结果生成")
            
    except KeyboardInterrupt:
        print("\n⚠️ 用户中断测试")
    except Exception as e:
        print(f"❌ 测试过程中发生错误: {e}")
    finally:
        # 清理资源
        benchmark.cleanup()

if __name__ == "__main__":
    main()