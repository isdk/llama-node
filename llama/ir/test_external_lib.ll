; ModuleID = 'test_external_lib.bc'
source_filename = "test_external_lib.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%"struct.__gnu_cxx::__ops::_Iter_less_iter" = type { i8 }

$_ZSt16__introsort_loopIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEElNS0_5__ops15_Iter_less_iterEEvT_S9_T0_T1_ = comdat any

$_ZSt22__final_insertion_sortIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEENS0_5__ops15_Iter_less_iterEEvT_S9_T0_ = comdat any

$_ZSt13__heap_selectIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEENS0_5__ops15_Iter_less_iterEEvT_S9_S9_T0_ = comdat any

$_ZSt11__make_heapIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEENS0_5__ops15_Iter_less_iterEEvT_S9_RT0_ = comdat any

; Function Attrs: mustprogress nounwind uwtable
define noundef float @compute_vector_norm(ptr noundef readonly captures(none) %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = shl nuw nsw i64 %1, 2
  %4 = icmp eq i64 %1, 0
  br i1 %4, label %5, label %7

5:                                                ; preds = %2
  %6 = getelementptr inbounds nuw i8, ptr null, i64 %3
  br label %10

7:                                                ; preds = %2
  %8 = tail call noalias noundef nonnull ptr @_Znwm(i64 noundef %3) #8
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 %3
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 4 %8, ptr align 4 %0, i64 %3, i1 false)
  br label %10

10:                                               ; preds = %5, %7
  %11 = phi ptr [ %6, %5 ], [ %9, %7 ]
  %12 = phi ptr [ null, %5 ], [ %8, %7 ]
  %13 = icmp eq ptr %12, %11
  br i1 %13, label %14, label %23

14:                                               ; preds = %23, %10
  %15 = phi float [ 0.000000e+00, %10 ], [ %27, %23 ]
  %16 = tail call noundef float @sqrtf(float noundef %15) #9, !tbaa !4
  %17 = icmp eq ptr %12, null
  br i1 %17, label %22, label %18

18:                                               ; preds = %14
  %19 = ptrtoint ptr %11 to i64
  %20 = ptrtoint ptr %12 to i64
  %21 = sub i64 %19, %20
  tail call void @_ZdlPvm(ptr noundef nonnull %12, i64 noundef %21) #10
  br label %22

22:                                               ; preds = %14, %18
  ret float %16

23:                                               ; preds = %10, %23
  %24 = phi float [ %27, %23 ], [ 0.000000e+00, %10 ]
  %25 = phi ptr [ %28, %23 ], [ %12, %10 ]
  %26 = load float, ptr %25, align 4, !tbaa !8
  %27 = tail call float @llvm.fmuladd.f32(float %26, float %26, float %24)
  %28 = getelementptr inbounds nuw i8, ptr %25, i64 4
  %29 = icmp eq ptr %28, %11
  br i1 %29, label %14, label %23
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.fmuladd.f32(float, float, float) #1

; Function Attrs: mustprogress nounwind uwtable
define void @sort_array(ptr noundef captures(none) %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = shl nuw nsw i64 %1, 2
  %4 = icmp eq i64 %1, 0
  br i1 %4, label %5, label %7

5:                                                ; preds = %2
  %6 = getelementptr inbounds nuw i8, ptr null, i64 %3
  br label %10

7:                                                ; preds = %2
  %8 = tail call noalias noundef nonnull ptr @_Znwm(i64 noundef %3) #8
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 %3
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 4 %8, ptr align 4 %0, i64 %3, i1 false)
  br label %10

10:                                               ; preds = %5, %7
  %11 = phi ptr [ %6, %5 ], [ %9, %7 ]
  %12 = phi ptr [ null, %5 ], [ %8, %7 ]
  %13 = icmp eq ptr %12, %11
  %14 = ptrtoint ptr %11 to i64
  br i1 %13, label %22, label %15

15:                                               ; preds = %10
  %16 = ptrtoint ptr %12 to i64
  %17 = sub i64 %14, %16
  %18 = ashr exact i64 %17, 2
  %19 = tail call range(i64 0, 65) i64 @llvm.ctlz.i64(i64 %18, i1 true)
  %20 = shl nuw nsw i64 %19, 1
  %21 = xor i64 %20, 126
  tail call void @_ZSt16__introsort_loopIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEElNS0_5__ops15_Iter_less_iterEEvT_S9_T0_T1_(ptr %12, ptr %11, i64 noundef %21)
  tail call void @_ZSt22__final_insertion_sortIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEENS0_5__ops15_Iter_less_iterEEvT_S9_T0_(ptr %12, ptr %11)
  tail call void @llvm.memcpy.p0.p0.i64(ptr align 4 %0, ptr align 4 %12, i64 %17, i1 false)
  br label %22

22:                                               ; preds = %10, %15
  %23 = phi i64 [ %16, %15 ], [ %14, %10 ]
  %24 = icmp eq ptr %12, null
  br i1 %24, label %28, label %25

25:                                               ; preds = %22
  %26 = ptrtoint ptr %11 to i64
  %27 = sub i64 %26, %23
  tail call void @_ZdlPvm(ptr noundef nonnull %12, i64 noundef %27) #10
  br label %28

28:                                               ; preds = %22, %25
  ret void
}

; Function Attrs: mustprogress nounwind uwtable
define i32 @find_max(ptr noundef readonly captures(none) %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = shl nuw nsw i64 %1, 2
  %4 = icmp ne i64 %1, 0
  tail call void @llvm.assume(i1 %4)
  %5 = tail call noalias noundef nonnull ptr @_Znwm(i64 noundef %3) #8
  %6 = getelementptr inbounds nuw i8, ptr %5, i64 %3
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 4 %5, ptr align 4 %0, i64 %3, i1 false)
  %7 = icmp eq i64 %1, 1
  br i1 %7, label %60, label %8

8:                                                ; preds = %2
  %9 = getelementptr inbounds nuw i8, ptr %5, i64 4
  %10 = load i32, ptr %5, align 4, !tbaa !4
  %11 = add nsw i64 %3, -8
  %12 = lshr exact i64 %11, 2
  %13 = add nuw nsw i64 %12, 1
  %14 = and i64 %13, 3
  %15 = and i64 %11, 12
  %16 = icmp eq i64 %15, 12
  br i1 %16, label %29, label %17

17:                                               ; preds = %8, %17
  %18 = phi i32 [ %24, %17 ], [ %10, %8 ]
  %19 = phi ptr [ %26, %17 ], [ %9, %8 ]
  %20 = phi ptr [ %25, %17 ], [ %5, %8 ]
  %21 = phi i64 [ %27, %17 ], [ 0, %8 ]
  %22 = load i32, ptr %19, align 4, !tbaa !4
  %23 = icmp slt i32 %18, %22
  %24 = tail call i32 @llvm.smax.i32(i32 %18, i32 %22)
  %25 = select i1 %23, ptr %19, ptr %20
  %26 = getelementptr inbounds nuw i8, ptr %19, i64 4
  %27 = add i64 %21, 1
  %28 = icmp eq i64 %27, %14
  br i1 %28, label %29, label %17, !llvm.loop !10

29:                                               ; preds = %17, %8
  %30 = phi ptr [ poison, %8 ], [ %25, %17 ]
  %31 = phi i32 [ %10, %8 ], [ %24, %17 ]
  %32 = phi ptr [ %9, %8 ], [ %26, %17 ]
  %33 = phi ptr [ %5, %8 ], [ %25, %17 ]
  %34 = icmp ult i64 %11, 12
  br i1 %34, label %60, label %35

35:                                               ; preds = %29, %35
  %36 = phi i32 [ %56, %35 ], [ %31, %29 ]
  %37 = phi ptr [ %58, %35 ], [ %32, %29 ]
  %38 = phi ptr [ %57, %35 ], [ %33, %29 ]
  %39 = load i32, ptr %37, align 4, !tbaa !4
  %40 = icmp slt i32 %36, %39
  %41 = tail call i32 @llvm.smax.i32(i32 %36, i32 %39)
  %42 = select i1 %40, ptr %37, ptr %38
  %43 = getelementptr inbounds nuw i8, ptr %37, i64 4
  %44 = load i32, ptr %43, align 4, !tbaa !4
  %45 = icmp slt i32 %41, %44
  %46 = tail call i32 @llvm.smax.i32(i32 %41, i32 %44)
  %47 = select i1 %45, ptr %43, ptr %42
  %48 = getelementptr inbounds nuw i8, ptr %37, i64 8
  %49 = load i32, ptr %48, align 4, !tbaa !4
  %50 = icmp slt i32 %46, %49
  %51 = tail call i32 @llvm.smax.i32(i32 %46, i32 %49)
  %52 = select i1 %50, ptr %48, ptr %47
  %53 = getelementptr inbounds nuw i8, ptr %37, i64 12
  %54 = load i32, ptr %53, align 4, !tbaa !4
  %55 = icmp slt i32 %51, %54
  %56 = tail call i32 @llvm.smax.i32(i32 %51, i32 %54)
  %57 = select i1 %55, ptr %53, ptr %52
  %58 = getelementptr inbounds nuw i8, ptr %37, i64 16
  %59 = icmp eq ptr %58, %6
  br i1 %59, label %60, label %35, !llvm.loop !12

60:                                               ; preds = %29, %35, %2
  %61 = phi ptr [ %5, %2 ], [ %30, %29 ], [ %57, %35 ]
  %62 = load i32, ptr %61, align 4, !tbaa !4
  tail call void @_ZdlPvm(ptr noundef nonnull %5, i64 noundef %3) #10
  ret i32 %62
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) uwtable
define float @compute_mean_float(ptr noundef readonly captures(none) %0, i64 noundef %1) local_unnamed_addr #2 {
  %3 = icmp eq i64 %1, 0
  br i1 %3, label %63, label %4

4:                                                ; preds = %2
  %5 = and i64 %1, 7
  %6 = icmp ult i64 %1, 8
  br i1 %6, label %49, label %7

7:                                                ; preds = %4
  %8 = and i64 %1, -8
  br label %9

9:                                                ; preds = %9, %7
  %10 = phi i64 [ 0, %7 ], [ %44, %9 ]
  %11 = phi float [ 0.000000e+00, %7 ], [ %43, %9 ]
  %12 = phi i64 [ 0, %7 ], [ %45, %9 ]
  %13 = getelementptr inbounds nuw float, ptr %0, i64 %10
  %14 = load float, ptr %13, align 4, !tbaa !8
  %15 = fadd float %11, %14
  %16 = getelementptr inbounds nuw float, ptr %0, i64 %10
  %17 = getelementptr inbounds nuw i8, ptr %16, i64 4
  %18 = load float, ptr %17, align 4, !tbaa !8
  %19 = fadd float %15, %18
  %20 = getelementptr inbounds nuw float, ptr %0, i64 %10
  %21 = getelementptr inbounds nuw i8, ptr %20, i64 8
  %22 = load float, ptr %21, align 4, !tbaa !8
  %23 = fadd float %19, %22
  %24 = getelementptr inbounds nuw float, ptr %0, i64 %10
  %25 = getelementptr inbounds nuw i8, ptr %24, i64 12
  %26 = load float, ptr %25, align 4, !tbaa !8
  %27 = fadd float %23, %26
  %28 = getelementptr inbounds nuw float, ptr %0, i64 %10
  %29 = getelementptr inbounds nuw i8, ptr %28, i64 16
  %30 = load float, ptr %29, align 4, !tbaa !8
  %31 = fadd float %27, %30
  %32 = getelementptr inbounds nuw float, ptr %0, i64 %10
  %33 = getelementptr inbounds nuw i8, ptr %32, i64 20
  %34 = load float, ptr %33, align 4, !tbaa !8
  %35 = fadd float %31, %34
  %36 = getelementptr inbounds nuw float, ptr %0, i64 %10
  %37 = getelementptr inbounds nuw i8, ptr %36, i64 24
  %38 = load float, ptr %37, align 4, !tbaa !8
  %39 = fadd float %35, %38
  %40 = getelementptr inbounds nuw float, ptr %0, i64 %10
  %41 = getelementptr inbounds nuw i8, ptr %40, i64 28
  %42 = load float, ptr %41, align 4, !tbaa !8
  %43 = fadd float %39, %42
  %44 = add nuw i64 %10, 8
  %45 = add i64 %12, 8
  %46 = icmp eq i64 %45, %8
  br i1 %46, label %47, label %9, !llvm.loop !14

47:                                               ; preds = %9
  %48 = icmp eq i64 %5, 0
  br i1 %48, label %63, label %49

49:                                               ; preds = %47, %4
  %50 = phi i64 [ 0, %4 ], [ %44, %47 ]
  %51 = phi float [ 0.000000e+00, %4 ], [ %43, %47 ]
  %52 = icmp ne i64 %5, 0
  tail call void @llvm.assume(i1 %52)
  br label %53

53:                                               ; preds = %53, %49
  %54 = phi i64 [ %60, %53 ], [ %50, %49 ]
  %55 = phi float [ %59, %53 ], [ %51, %49 ]
  %56 = phi i64 [ %61, %53 ], [ 0, %49 ]
  %57 = getelementptr inbounds nuw float, ptr %0, i64 %54
  %58 = load float, ptr %57, align 4, !tbaa !8
  %59 = fadd float %55, %58
  %60 = add nuw i64 %54, 1
  %61 = add i64 %56, 1
  %62 = icmp eq i64 %61, %5
  br i1 %62, label %63, label %53, !llvm.loop !15

63:                                               ; preds = %47, %53, %2
  %64 = phi float [ 0.000000e+00, %2 ], [ %43, %47 ], [ %59, %53 ]
  %65 = uitofp i64 %1 to float
  %66 = fdiv float %64, %65
  ret float %66
}

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(errnomem: write)
declare float @sqrtf(float noundef) local_unnamed_addr #3

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i64, i1 immarg) #4

; Function Attrs: nobuiltin allocsize(0)
declare noundef nonnull ptr @_Znwm(i64 noundef) local_unnamed_addr #5

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memmove.p0.p0.i64(ptr writeonly captures(none), ptr readonly captures(none), i64, i1 immarg) #4

; Function Attrs: nobuiltin nounwind
declare void @_ZdlPvm(ptr noundef, i64 noundef) local_unnamed_addr #6

; Function Attrs: mustprogress nounwind uwtable
define linkonce_odr void @_ZSt16__introsort_loopIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEElNS0_5__ops15_Iter_less_iterEEvT_S9_T0_T1_(ptr %0, ptr %1, i64 noundef %2) local_unnamed_addr #0 comdat {
  %4 = ptrtoint ptr %0 to i64
  %5 = ptrtoint ptr %1 to i64
  %6 = sub i64 %5, %4
  %7 = ashr exact i64 %6, 2
  %8 = icmp sgt i64 %7, 16
  br i1 %8, label %9, label %125

9:                                                ; preds = %3
  %10 = getelementptr inbounds nuw i8, ptr %0, i64 4
  br label %11

11:                                               ; preds = %9, %120
  %12 = phi i64 [ %7, %9 ], [ %123, %120 ]
  %13 = phi i64 [ %2, %9 ], [ %76, %120 ]
  %14 = phi ptr [ %1, %9 ], [ %108, %120 ]
  %15 = icmp eq i64 %13, 0
  br i1 %15, label %16, label %75

16:                                               ; preds = %11
  tail call void @_ZSt13__heap_selectIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEENS0_5__ops15_Iter_less_iterEEvT_S9_S9_T0_(ptr %0, ptr %14, ptr %14)
  br label %17

17:                                               ; preds = %16, %71
  %18 = phi ptr [ %19, %71 ], [ %14, %16 ]
  %19 = getelementptr inbounds i8, ptr %18, i64 -4
  %20 = load i32, ptr %19, align 4, !tbaa !4
  %21 = load i32, ptr %0, align 4, !tbaa !4
  store i32 %21, ptr %19, align 4, !tbaa !4
  %22 = ptrtoint ptr %19 to i64
  %23 = sub i64 %22, %4
  %24 = ashr exact i64 %23, 2
  %25 = add nsw i64 %24, -1
  %26 = sdiv i64 %25, 2
  %27 = icmp sgt i64 %24, 2
  br i1 %27, label %28, label %43

28:                                               ; preds = %17, %28
  %29 = phi i64 [ %38, %28 ], [ 0, %17 ]
  %30 = shl i64 %29, 1
  %31 = add i64 %30, 2
  %32 = getelementptr inbounds i32, ptr %0, i64 %31
  %33 = or disjoint i64 %30, 1
  %34 = getelementptr inbounds i32, ptr %0, i64 %33
  %35 = load i32, ptr %32, align 4, !tbaa !4
  %36 = load i32, ptr %34, align 4, !tbaa !4
  %37 = icmp slt i32 %35, %36
  %38 = select i1 %37, i64 %33, i64 %31
  %39 = getelementptr inbounds i32, ptr %0, i64 %38
  %40 = load i32, ptr %39, align 4, !tbaa !4
  %41 = getelementptr inbounds i32, ptr %0, i64 %29
  store i32 %40, ptr %41, align 4, !tbaa !4
  %42 = icmp slt i64 %38, %26
  br i1 %42, label %28, label %43, !llvm.loop !16

43:                                               ; preds = %28, %17
  %44 = phi i64 [ 0, %17 ], [ %38, %28 ]
  %45 = and i64 %23, 4
  %46 = icmp eq i64 %45, 0
  br i1 %46, label %47, label %57

47:                                               ; preds = %43
  %48 = add nsw i64 %24, -2
  %49 = ashr exact i64 %48, 1
  %50 = icmp eq i64 %44, %49
  br i1 %50, label %51, label %57

51:                                               ; preds = %47
  %52 = shl nuw nsw i64 %44, 1
  %53 = or disjoint i64 %52, 1
  %54 = getelementptr inbounds nuw i32, ptr %0, i64 %53
  %55 = load i32, ptr %54, align 4, !tbaa !4
  %56 = getelementptr inbounds i32, ptr %0, i64 %44
  store i32 %55, ptr %56, align 4, !tbaa !4
  br label %59

57:                                               ; preds = %47, %43
  %58 = icmp eq i64 %44, 0
  br i1 %58, label %71, label %59

59:                                               ; preds = %57, %51
  %60 = phi i64 [ %44, %57 ], [ %53, %51 ]
  br label %61

61:                                               ; preds = %59, %68
  %62 = phi i64 [ %64, %68 ], [ %60, %59 ]
  %63 = add nsw i64 %62, -1
  %64 = lshr i64 %63, 1
  %65 = getelementptr inbounds nuw i32, ptr %0, i64 %64
  %66 = load i32, ptr %65, align 4, !tbaa !4
  %67 = icmp slt i32 %66, %20
  br i1 %67, label %68, label %71

68:                                               ; preds = %61
  %69 = getelementptr inbounds i32, ptr %0, i64 %62
  store i32 %66, ptr %69, align 4, !tbaa !4
  %70 = icmp ult i64 %63, 2
  br i1 %70, label %71, label %61, !llvm.loop !17

71:                                               ; preds = %68, %61, %57
  %72 = phi i64 [ 0, %57 ], [ %62, %61 ], [ 0, %68 ]
  %73 = getelementptr inbounds i32, ptr %0, i64 %72
  store i32 %20, ptr %73, align 4, !tbaa !4
  %74 = icmp sgt i64 %23, 4
  br i1 %74, label %17, label %125, !llvm.loop !18

75:                                               ; preds = %11
  %76 = add nsw i64 %13, -1
  %77 = lshr i64 %12, 1
  %78 = getelementptr inbounds nuw i32, ptr %0, i64 %77
  %79 = getelementptr inbounds i8, ptr %14, i64 -4
  %80 = load i32, ptr %10, align 4, !tbaa !4
  %81 = load i32, ptr %78, align 4, !tbaa !4
  %82 = icmp slt i32 %80, %81
  %83 = load i32, ptr %79, align 4, !tbaa !4
  br i1 %82, label %84, label %93

84:                                               ; preds = %75
  %85 = icmp slt i32 %81, %83
  br i1 %85, label %86, label %88

86:                                               ; preds = %84
  %87 = load i32, ptr %0, align 4, !tbaa !4
  store i32 %81, ptr %0, align 4, !tbaa !4
  store i32 %87, ptr %78, align 4, !tbaa !4
  br label %102

88:                                               ; preds = %84
  %89 = icmp slt i32 %80, %83
  %90 = load i32, ptr %0, align 4, !tbaa !4
  br i1 %89, label %91, label %92

91:                                               ; preds = %88
  store i32 %83, ptr %0, align 4, !tbaa !4
  store i32 %90, ptr %79, align 4, !tbaa !4
  br label %102

92:                                               ; preds = %88
  store i32 %80, ptr %0, align 4, !tbaa !4
  store i32 %90, ptr %10, align 4, !tbaa !4
  br label %102

93:                                               ; preds = %75
  %94 = icmp slt i32 %80, %83
  br i1 %94, label %95, label %97

95:                                               ; preds = %93
  %96 = load i32, ptr %0, align 4, !tbaa !4
  store i32 %80, ptr %0, align 4, !tbaa !4
  store i32 %96, ptr %10, align 4, !tbaa !4
  br label %102

97:                                               ; preds = %93
  %98 = icmp slt i32 %81, %83
  %99 = load i32, ptr %0, align 4, !tbaa !4
  br i1 %98, label %100, label %101

100:                                              ; preds = %97
  store i32 %83, ptr %0, align 4, !tbaa !4
  store i32 %99, ptr %79, align 4, !tbaa !4
  br label %102

101:                                              ; preds = %97
  store i32 %81, ptr %0, align 4, !tbaa !4
  store i32 %99, ptr %78, align 4, !tbaa !4
  br label %102

102:                                              ; preds = %101, %100, %95, %92, %91, %86
  br label %103

103:                                              ; preds = %102, %119
  %104 = phi ptr [ %111, %119 ], [ %10, %102 ]
  %105 = phi ptr [ %114, %119 ], [ %14, %102 ]
  %106 = load i32, ptr %0, align 4, !tbaa !4
  br label %107

107:                                              ; preds = %107, %103
  %108 = phi ptr [ %104, %103 ], [ %111, %107 ]
  %109 = load i32, ptr %108, align 4, !tbaa !4
  %110 = icmp slt i32 %109, %106
  %111 = getelementptr inbounds nuw i8, ptr %108, i64 4
  br i1 %110, label %107, label %112, !llvm.loop !19

112:                                              ; preds = %107, %112
  %113 = phi ptr [ %114, %112 ], [ %105, %107 ]
  %114 = getelementptr inbounds i8, ptr %113, i64 -4
  %115 = load i32, ptr %114, align 4, !tbaa !4
  %116 = icmp slt i32 %106, %115
  br i1 %116, label %112, label %117, !llvm.loop !20

117:                                              ; preds = %112
  %118 = icmp ult ptr %108, %114
  br i1 %118, label %119, label %120

119:                                              ; preds = %117
  store i32 %115, ptr %108, align 4, !tbaa !4
  store i32 %109, ptr %114, align 4, !tbaa !4
  br label %103, !llvm.loop !21

120:                                              ; preds = %117
  tail call void @_ZSt16__introsort_loopIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEElNS0_5__ops15_Iter_less_iterEEvT_S9_T0_T1_(ptr nonnull %108, ptr %14, i64 noundef %76)
  %121 = ptrtoint ptr %108 to i64
  %122 = sub i64 %121, %4
  %123 = ashr exact i64 %122, 2
  %124 = icmp sgt i64 %123, 16
  br i1 %124, label %11, label %125, !llvm.loop !22

125:                                              ; preds = %120, %71, %3
  ret void
}

; Function Attrs: mustprogress nounwind uwtable
define linkonce_odr void @_ZSt22__final_insertion_sortIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEENS0_5__ops15_Iter_less_iterEEvT_S9_T0_(ptr %0, ptr %1) local_unnamed_addr #0 comdat {
  %3 = ptrtoint ptr %1 to i64
  %4 = ptrtoint ptr %0 to i64
  %5 = sub i64 %3, %4
  %6 = icmp sgt i64 %5, 64
  br i1 %6, label %7, label %274

7:                                                ; preds = %2
  %8 = getelementptr i8, ptr %0, i64 4
  %9 = load i32, ptr %8, align 4, !tbaa !4
  %10 = load i32, ptr %0, align 4, !tbaa !4
  %11 = icmp slt i32 %9, %10
  br i1 %11, label %12, label %14

12:                                               ; preds = %7
  %13 = load i32, ptr %0, align 4
  store i32 %13, ptr %8, align 4
  br label %14

14:                                               ; preds = %7, %12
  %15 = phi ptr [ %0, %12 ], [ %8, %7 ]
  store i32 %9, ptr %15, align 4, !tbaa !4
  %16 = getelementptr inbounds nuw i8, ptr %0, i64 8
  %17 = load i32, ptr %16, align 4, !tbaa !4
  %18 = load i32, ptr %0, align 4, !tbaa !4
  %19 = icmp slt i32 %17, %18
  br i1 %19, label %30, label %20

20:                                               ; preds = %14
  %21 = load i32, ptr %8, align 4, !tbaa !4
  %22 = icmp slt i32 %17, %21
  br i1 %22, label %23, label %32

23:                                               ; preds = %20, %23
  %24 = phi i32 [ %28, %23 ], [ %21, %20 ]
  %25 = phi ptr [ %27, %23 ], [ %8, %20 ]
  %26 = phi ptr [ %25, %23 ], [ %16, %20 ]
  store i32 %24, ptr %26, align 4, !tbaa !4
  %27 = getelementptr inbounds i8, ptr %25, i64 -4
  %28 = load i32, ptr %27, align 4, !tbaa !4
  %29 = icmp slt i32 %17, %28
  br i1 %29, label %23, label %32, !llvm.loop !23

30:                                               ; preds = %14
  %31 = load i64, ptr %0, align 4
  store i64 %31, ptr %8, align 4
  br label %32

32:                                               ; preds = %23, %30, %20
  %33 = phi ptr [ %0, %30 ], [ %16, %20 ], [ %25, %23 ]
  store i32 %17, ptr %33, align 4, !tbaa !4
  %34 = getelementptr inbounds nuw i8, ptr %0, i64 12
  %35 = load i32, ptr %34, align 4, !tbaa !4
  %36 = load i32, ptr %0, align 4, !tbaa !4
  %37 = icmp slt i32 %35, %36
  br i1 %37, label %48, label %38

38:                                               ; preds = %32
  %39 = load i32, ptr %16, align 4, !tbaa !4
  %40 = icmp slt i32 %35, %39
  br i1 %40, label %41, label %49

41:                                               ; preds = %38, %41
  %42 = phi i32 [ %46, %41 ], [ %39, %38 ]
  %43 = phi ptr [ %45, %41 ], [ %16, %38 ]
  %44 = phi ptr [ %43, %41 ], [ %34, %38 ]
  store i32 %42, ptr %44, align 4, !tbaa !4
  %45 = getelementptr inbounds i8, ptr %43, i64 -4
  %46 = load i32, ptr %45, align 4, !tbaa !4
  %47 = icmp slt i32 %35, %46
  br i1 %47, label %41, label %49, !llvm.loop !23

48:                                               ; preds = %32
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(12) %8, ptr noundef nonnull align 4 dereferenceable(12) %0, i64 12, i1 false)
  br label %49

49:                                               ; preds = %41, %48, %38
  %50 = phi ptr [ %0, %48 ], [ %34, %38 ], [ %43, %41 ]
  store i32 %35, ptr %50, align 4, !tbaa !4
  %51 = getelementptr inbounds nuw i8, ptr %0, i64 16
  %52 = load i32, ptr %51, align 4, !tbaa !4
  %53 = load i32, ptr %0, align 4, !tbaa !4
  %54 = icmp slt i32 %52, %53
  br i1 %54, label %65, label %55

55:                                               ; preds = %49
  %56 = load i32, ptr %34, align 4, !tbaa !4
  %57 = icmp slt i32 %52, %56
  br i1 %57, label %58, label %66

58:                                               ; preds = %55, %58
  %59 = phi i32 [ %63, %58 ], [ %56, %55 ]
  %60 = phi ptr [ %62, %58 ], [ %34, %55 ]
  %61 = phi ptr [ %60, %58 ], [ %51, %55 ]
  store i32 %59, ptr %61, align 4, !tbaa !4
  %62 = getelementptr inbounds i8, ptr %60, i64 -4
  %63 = load i32, ptr %62, align 4, !tbaa !4
  %64 = icmp slt i32 %52, %63
  br i1 %64, label %58, label %66, !llvm.loop !23

65:                                               ; preds = %49
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(16) %8, ptr noundef nonnull align 4 dereferenceable(16) %0, i64 16, i1 false)
  br label %66

66:                                               ; preds = %58, %65, %55
  %67 = phi ptr [ %0, %65 ], [ %51, %55 ], [ %60, %58 ]
  store i32 %52, ptr %67, align 4, !tbaa !4
  %68 = getelementptr inbounds nuw i8, ptr %0, i64 20
  %69 = load i32, ptr %68, align 4, !tbaa !4
  %70 = load i32, ptr %0, align 4, !tbaa !4
  %71 = icmp slt i32 %69, %70
  br i1 %71, label %82, label %72

72:                                               ; preds = %66
  %73 = load i32, ptr %51, align 4, !tbaa !4
  %74 = icmp slt i32 %69, %73
  br i1 %74, label %75, label %83

75:                                               ; preds = %72, %75
  %76 = phi i32 [ %80, %75 ], [ %73, %72 ]
  %77 = phi ptr [ %79, %75 ], [ %51, %72 ]
  %78 = phi ptr [ %77, %75 ], [ %68, %72 ]
  store i32 %76, ptr %78, align 4, !tbaa !4
  %79 = getelementptr inbounds i8, ptr %77, i64 -4
  %80 = load i32, ptr %79, align 4, !tbaa !4
  %81 = icmp slt i32 %69, %80
  br i1 %81, label %75, label %83, !llvm.loop !23

82:                                               ; preds = %66
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(20) %8, ptr noundef nonnull align 4 dereferenceable(20) %0, i64 20, i1 false)
  br label %83

83:                                               ; preds = %75, %82, %72
  %84 = phi ptr [ %0, %82 ], [ %68, %72 ], [ %77, %75 ]
  store i32 %69, ptr %84, align 4, !tbaa !4
  %85 = getelementptr inbounds nuw i8, ptr %0, i64 24
  %86 = load i32, ptr %85, align 4, !tbaa !4
  %87 = load i32, ptr %0, align 4, !tbaa !4
  %88 = icmp slt i32 %86, %87
  br i1 %88, label %99, label %89

89:                                               ; preds = %83
  %90 = load i32, ptr %68, align 4, !tbaa !4
  %91 = icmp slt i32 %86, %90
  br i1 %91, label %92, label %100

92:                                               ; preds = %89, %92
  %93 = phi i32 [ %97, %92 ], [ %90, %89 ]
  %94 = phi ptr [ %96, %92 ], [ %68, %89 ]
  %95 = phi ptr [ %94, %92 ], [ %85, %89 ]
  store i32 %93, ptr %95, align 4, !tbaa !4
  %96 = getelementptr inbounds i8, ptr %94, i64 -4
  %97 = load i32, ptr %96, align 4, !tbaa !4
  %98 = icmp slt i32 %86, %97
  br i1 %98, label %92, label %100, !llvm.loop !23

99:                                               ; preds = %83
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(24) %8, ptr noundef nonnull align 4 dereferenceable(24) %0, i64 24, i1 false)
  br label %100

100:                                              ; preds = %92, %99, %89
  %101 = phi ptr [ %0, %99 ], [ %85, %89 ], [ %94, %92 ]
  store i32 %86, ptr %101, align 4, !tbaa !4
  %102 = getelementptr inbounds nuw i8, ptr %0, i64 28
  %103 = load i32, ptr %102, align 4, !tbaa !4
  %104 = load i32, ptr %0, align 4, !tbaa !4
  %105 = icmp slt i32 %103, %104
  br i1 %105, label %116, label %106

106:                                              ; preds = %100
  %107 = load i32, ptr %85, align 4, !tbaa !4
  %108 = icmp slt i32 %103, %107
  br i1 %108, label %109, label %117

109:                                              ; preds = %106, %109
  %110 = phi i32 [ %114, %109 ], [ %107, %106 ]
  %111 = phi ptr [ %113, %109 ], [ %85, %106 ]
  %112 = phi ptr [ %111, %109 ], [ %102, %106 ]
  store i32 %110, ptr %112, align 4, !tbaa !4
  %113 = getelementptr inbounds i8, ptr %111, i64 -4
  %114 = load i32, ptr %113, align 4, !tbaa !4
  %115 = icmp slt i32 %103, %114
  br i1 %115, label %109, label %117, !llvm.loop !23

116:                                              ; preds = %100
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(28) %8, ptr noundef nonnull align 4 dereferenceable(28) %0, i64 28, i1 false)
  br label %117

117:                                              ; preds = %109, %116, %106
  %118 = phi ptr [ %0, %116 ], [ %102, %106 ], [ %111, %109 ]
  store i32 %103, ptr %118, align 4, !tbaa !4
  %119 = getelementptr inbounds nuw i8, ptr %0, i64 32
  %120 = load i32, ptr %119, align 4, !tbaa !4
  %121 = load i32, ptr %0, align 4, !tbaa !4
  %122 = icmp slt i32 %120, %121
  br i1 %122, label %133, label %123

123:                                              ; preds = %117
  %124 = load i32, ptr %102, align 4, !tbaa !4
  %125 = icmp slt i32 %120, %124
  br i1 %125, label %126, label %134

126:                                              ; preds = %123, %126
  %127 = phi i32 [ %131, %126 ], [ %124, %123 ]
  %128 = phi ptr [ %130, %126 ], [ %102, %123 ]
  %129 = phi ptr [ %128, %126 ], [ %119, %123 ]
  store i32 %127, ptr %129, align 4, !tbaa !4
  %130 = getelementptr inbounds i8, ptr %128, i64 -4
  %131 = load i32, ptr %130, align 4, !tbaa !4
  %132 = icmp slt i32 %120, %131
  br i1 %132, label %126, label %134, !llvm.loop !23

133:                                              ; preds = %117
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(32) %8, ptr noundef nonnull align 4 dereferenceable(32) %0, i64 32, i1 false)
  br label %134

134:                                              ; preds = %126, %133, %123
  %135 = phi ptr [ %0, %133 ], [ %119, %123 ], [ %128, %126 ]
  store i32 %120, ptr %135, align 4, !tbaa !4
  %136 = getelementptr inbounds nuw i8, ptr %0, i64 36
  %137 = load i32, ptr %136, align 4, !tbaa !4
  %138 = load i32, ptr %0, align 4, !tbaa !4
  %139 = icmp slt i32 %137, %138
  br i1 %139, label %150, label %140

140:                                              ; preds = %134
  %141 = load i32, ptr %119, align 4, !tbaa !4
  %142 = icmp slt i32 %137, %141
  br i1 %142, label %143, label %151

143:                                              ; preds = %140, %143
  %144 = phi i32 [ %148, %143 ], [ %141, %140 ]
  %145 = phi ptr [ %147, %143 ], [ %119, %140 ]
  %146 = phi ptr [ %145, %143 ], [ %136, %140 ]
  store i32 %144, ptr %146, align 4, !tbaa !4
  %147 = getelementptr inbounds i8, ptr %145, i64 -4
  %148 = load i32, ptr %147, align 4, !tbaa !4
  %149 = icmp slt i32 %137, %148
  br i1 %149, label %143, label %151, !llvm.loop !23

150:                                              ; preds = %134
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(36) %8, ptr noundef nonnull align 4 dereferenceable(36) %0, i64 36, i1 false)
  br label %151

151:                                              ; preds = %143, %150, %140
  %152 = phi ptr [ %0, %150 ], [ %136, %140 ], [ %145, %143 ]
  store i32 %137, ptr %152, align 4, !tbaa !4
  %153 = getelementptr inbounds nuw i8, ptr %0, i64 40
  %154 = load i32, ptr %153, align 4, !tbaa !4
  %155 = load i32, ptr %0, align 4, !tbaa !4
  %156 = icmp slt i32 %154, %155
  br i1 %156, label %167, label %157

157:                                              ; preds = %151
  %158 = load i32, ptr %136, align 4, !tbaa !4
  %159 = icmp slt i32 %154, %158
  br i1 %159, label %160, label %168

160:                                              ; preds = %157, %160
  %161 = phi i32 [ %165, %160 ], [ %158, %157 ]
  %162 = phi ptr [ %164, %160 ], [ %136, %157 ]
  %163 = phi ptr [ %162, %160 ], [ %153, %157 ]
  store i32 %161, ptr %163, align 4, !tbaa !4
  %164 = getelementptr inbounds i8, ptr %162, i64 -4
  %165 = load i32, ptr %164, align 4, !tbaa !4
  %166 = icmp slt i32 %154, %165
  br i1 %166, label %160, label %168, !llvm.loop !23

167:                                              ; preds = %151
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(40) %8, ptr noundef nonnull align 4 dereferenceable(40) %0, i64 40, i1 false)
  br label %168

168:                                              ; preds = %160, %167, %157
  %169 = phi ptr [ %0, %167 ], [ %153, %157 ], [ %162, %160 ]
  store i32 %154, ptr %169, align 4, !tbaa !4
  %170 = getelementptr inbounds nuw i8, ptr %0, i64 44
  %171 = load i32, ptr %170, align 4, !tbaa !4
  %172 = load i32, ptr %0, align 4, !tbaa !4
  %173 = icmp slt i32 %171, %172
  br i1 %173, label %184, label %174

174:                                              ; preds = %168
  %175 = load i32, ptr %153, align 4, !tbaa !4
  %176 = icmp slt i32 %171, %175
  br i1 %176, label %177, label %185

177:                                              ; preds = %174, %177
  %178 = phi i32 [ %182, %177 ], [ %175, %174 ]
  %179 = phi ptr [ %181, %177 ], [ %153, %174 ]
  %180 = phi ptr [ %179, %177 ], [ %170, %174 ]
  store i32 %178, ptr %180, align 4, !tbaa !4
  %181 = getelementptr inbounds i8, ptr %179, i64 -4
  %182 = load i32, ptr %181, align 4, !tbaa !4
  %183 = icmp slt i32 %171, %182
  br i1 %183, label %177, label %185, !llvm.loop !23

184:                                              ; preds = %168
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(44) %8, ptr noundef nonnull align 4 dereferenceable(44) %0, i64 44, i1 false)
  br label %185

185:                                              ; preds = %177, %184, %174
  %186 = phi ptr [ %0, %184 ], [ %170, %174 ], [ %179, %177 ]
  store i32 %171, ptr %186, align 4, !tbaa !4
  %187 = getelementptr inbounds nuw i8, ptr %0, i64 48
  %188 = load i32, ptr %187, align 4, !tbaa !4
  %189 = load i32, ptr %0, align 4, !tbaa !4
  %190 = icmp slt i32 %188, %189
  br i1 %190, label %201, label %191

191:                                              ; preds = %185
  %192 = load i32, ptr %170, align 4, !tbaa !4
  %193 = icmp slt i32 %188, %192
  br i1 %193, label %194, label %202

194:                                              ; preds = %191, %194
  %195 = phi i32 [ %199, %194 ], [ %192, %191 ]
  %196 = phi ptr [ %198, %194 ], [ %170, %191 ]
  %197 = phi ptr [ %196, %194 ], [ %187, %191 ]
  store i32 %195, ptr %197, align 4, !tbaa !4
  %198 = getelementptr inbounds i8, ptr %196, i64 -4
  %199 = load i32, ptr %198, align 4, !tbaa !4
  %200 = icmp slt i32 %188, %199
  br i1 %200, label %194, label %202, !llvm.loop !23

201:                                              ; preds = %185
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(48) %8, ptr noundef nonnull align 4 dereferenceable(48) %0, i64 48, i1 false)
  br label %202

202:                                              ; preds = %194, %201, %191
  %203 = phi ptr [ %0, %201 ], [ %187, %191 ], [ %196, %194 ]
  store i32 %188, ptr %203, align 4, !tbaa !4
  %204 = getelementptr inbounds nuw i8, ptr %0, i64 52
  %205 = load i32, ptr %204, align 4, !tbaa !4
  %206 = load i32, ptr %0, align 4, !tbaa !4
  %207 = icmp slt i32 %205, %206
  br i1 %207, label %218, label %208

208:                                              ; preds = %202
  %209 = load i32, ptr %187, align 4, !tbaa !4
  %210 = icmp slt i32 %205, %209
  br i1 %210, label %211, label %219

211:                                              ; preds = %208, %211
  %212 = phi i32 [ %216, %211 ], [ %209, %208 ]
  %213 = phi ptr [ %215, %211 ], [ %187, %208 ]
  %214 = phi ptr [ %213, %211 ], [ %204, %208 ]
  store i32 %212, ptr %214, align 4, !tbaa !4
  %215 = getelementptr inbounds i8, ptr %213, i64 -4
  %216 = load i32, ptr %215, align 4, !tbaa !4
  %217 = icmp slt i32 %205, %216
  br i1 %217, label %211, label %219, !llvm.loop !23

218:                                              ; preds = %202
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(52) %8, ptr noundef nonnull align 4 dereferenceable(52) %0, i64 52, i1 false)
  br label %219

219:                                              ; preds = %211, %218, %208
  %220 = phi ptr [ %0, %218 ], [ %204, %208 ], [ %213, %211 ]
  store i32 %205, ptr %220, align 4, !tbaa !4
  %221 = getelementptr inbounds nuw i8, ptr %0, i64 56
  %222 = load i32, ptr %221, align 4, !tbaa !4
  %223 = load i32, ptr %0, align 4, !tbaa !4
  %224 = icmp slt i32 %222, %223
  br i1 %224, label %235, label %225

225:                                              ; preds = %219
  %226 = load i32, ptr %204, align 4, !tbaa !4
  %227 = icmp slt i32 %222, %226
  br i1 %227, label %228, label %236

228:                                              ; preds = %225, %228
  %229 = phi i32 [ %233, %228 ], [ %226, %225 ]
  %230 = phi ptr [ %232, %228 ], [ %204, %225 ]
  %231 = phi ptr [ %230, %228 ], [ %221, %225 ]
  store i32 %229, ptr %231, align 4, !tbaa !4
  %232 = getelementptr inbounds i8, ptr %230, i64 -4
  %233 = load i32, ptr %232, align 4, !tbaa !4
  %234 = icmp slt i32 %222, %233
  br i1 %234, label %228, label %236, !llvm.loop !23

235:                                              ; preds = %219
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(56) %8, ptr noundef nonnull align 4 dereferenceable(56) %0, i64 56, i1 false)
  br label %236

236:                                              ; preds = %228, %235, %225
  %237 = phi ptr [ %0, %235 ], [ %221, %225 ], [ %230, %228 ]
  store i32 %222, ptr %237, align 4, !tbaa !4
  %238 = getelementptr inbounds nuw i8, ptr %0, i64 60
  %239 = load i32, ptr %238, align 4, !tbaa !4
  %240 = load i32, ptr %0, align 4, !tbaa !4
  %241 = icmp slt i32 %239, %240
  br i1 %241, label %252, label %242

242:                                              ; preds = %236
  %243 = load i32, ptr %221, align 4, !tbaa !4
  %244 = icmp slt i32 %239, %243
  br i1 %244, label %245, label %253

245:                                              ; preds = %242, %245
  %246 = phi i32 [ %250, %245 ], [ %243, %242 ]
  %247 = phi ptr [ %249, %245 ], [ %221, %242 ]
  %248 = phi ptr [ %247, %245 ], [ %238, %242 ]
  store i32 %246, ptr %248, align 4, !tbaa !4
  %249 = getelementptr inbounds i8, ptr %247, i64 -4
  %250 = load i32, ptr %249, align 4, !tbaa !4
  %251 = icmp slt i32 %239, %250
  br i1 %251, label %245, label %253, !llvm.loop !23

252:                                              ; preds = %236
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(60) %8, ptr noundef nonnull align 4 dereferenceable(60) %0, i64 60, i1 false)
  br label %253

253:                                              ; preds = %245, %252, %242
  %254 = phi ptr [ %0, %252 ], [ %238, %242 ], [ %247, %245 ]
  store i32 %239, ptr %254, align 4, !tbaa !4
  %255 = getelementptr inbounds nuw i8, ptr %0, i64 64
  %256 = icmp eq ptr %255, %1
  br i1 %256, label %306, label %257

257:                                              ; preds = %253, %270
  %258 = phi ptr [ %272, %270 ], [ %255, %253 ]
  %259 = load i32, ptr %258, align 4, !tbaa !4
  %260 = getelementptr inbounds i8, ptr %258, i64 -4
  %261 = load i32, ptr %260, align 4, !tbaa !4
  %262 = icmp slt i32 %259, %261
  br i1 %262, label %263, label %270

263:                                              ; preds = %257, %263
  %264 = phi i32 [ %268, %263 ], [ %261, %257 ]
  %265 = phi ptr [ %267, %263 ], [ %260, %257 ]
  %266 = phi ptr [ %265, %263 ], [ %258, %257 ]
  store i32 %264, ptr %266, align 4, !tbaa !4
  %267 = getelementptr inbounds i8, ptr %265, i64 -4
  %268 = load i32, ptr %267, align 4, !tbaa !4
  %269 = icmp slt i32 %259, %268
  br i1 %269, label %263, label %270, !llvm.loop !23

270:                                              ; preds = %263, %257
  %271 = phi ptr [ %258, %257 ], [ %265, %263 ]
  store i32 %259, ptr %271, align 4, !tbaa !4
  %272 = getelementptr inbounds nuw i8, ptr %258, i64 4
  %273 = icmp eq ptr %272, %1
  br i1 %273, label %306, label %257, !llvm.loop !24

274:                                              ; preds = %2
  %275 = icmp eq ptr %0, %1
  %276 = getelementptr inbounds nuw i8, ptr %0, i64 4
  %277 = icmp eq ptr %276, %1
  %278 = select i1 %275, i1 true, i1 %277
  br i1 %278, label %306, label %279

279:                                              ; preds = %274, %302
  %280 = phi ptr [ %304, %302 ], [ %276, %274 ]
  %281 = phi ptr [ %280, %302 ], [ %0, %274 ]
  %282 = load i32, ptr %280, align 4, !tbaa !4
  %283 = load i32, ptr %0, align 4, !tbaa !4
  %284 = icmp slt i32 %282, %283
  br i1 %284, label %285, label %292

285:                                              ; preds = %279
  %286 = getelementptr inbounds nuw i8, ptr %281, i64 8
  %287 = ptrtoint ptr %280 to i64
  %288 = sub i64 %287, %4
  %289 = ashr exact i64 %288, 2
  %290 = sub nsw i64 0, %289
  %291 = getelementptr inbounds i32, ptr %286, i64 %290
  tail call void @llvm.memmove.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(1) %291, ptr noundef nonnull align 4 dereferenceable(1) %0, i64 %288, i1 false)
  br label %302

292:                                              ; preds = %279
  %293 = load i32, ptr %281, align 4, !tbaa !4
  %294 = icmp slt i32 %282, %293
  br i1 %294, label %295, label %302

295:                                              ; preds = %292, %295
  %296 = phi i32 [ %300, %295 ], [ %293, %292 ]
  %297 = phi ptr [ %299, %295 ], [ %281, %292 ]
  %298 = phi ptr [ %297, %295 ], [ %280, %292 ]
  store i32 %296, ptr %298, align 4, !tbaa !4
  %299 = getelementptr inbounds i8, ptr %297, i64 -4
  %300 = load i32, ptr %299, align 4, !tbaa !4
  %301 = icmp slt i32 %282, %300
  br i1 %301, label %295, label %302, !llvm.loop !23

302:                                              ; preds = %295, %292, %285
  %303 = phi ptr [ %0, %285 ], [ %280, %292 ], [ %297, %295 ]
  store i32 %282, ptr %303, align 4, !tbaa !4
  %304 = getelementptr inbounds nuw i8, ptr %280, i64 4
  %305 = icmp eq ptr %304, %1
  br i1 %305, label %306, label %279, !llvm.loop !25

306:                                              ; preds = %302, %270, %274, %253
  ret void
}

; Function Attrs: mustprogress nounwind uwtable
define linkonce_odr void @_ZSt13__heap_selectIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEENS0_5__ops15_Iter_less_iterEEvT_S9_S9_T0_(ptr %0, ptr %1, ptr %2) local_unnamed_addr #0 comdat {
  %4 = alloca %"struct.__gnu_cxx::__ops::_Iter_less_iter", align 1
  %5 = freeze ptr %0
  %6 = freeze ptr %1
  call void @_ZSt11__make_heapIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEENS0_5__ops15_Iter_less_iterEEvT_S9_RT0_(ptr %5, ptr %6, ptr noundef nonnull align 1 dereferenceable(1) %4)
  %7 = icmp ult ptr %6, %2
  br i1 %7, label %8, label %101

8:                                                ; preds = %3
  %9 = ptrtoint ptr %6 to i64
  %10 = ptrtoint ptr %5 to i64
  %11 = sub i64 %9, %10
  %12 = ashr i64 %11, 2
  %13 = add nsw i64 %12, -1
  %14 = sdiv i64 %13, 2
  %15 = icmp sgt i64 %12, 2
  %16 = and i64 %11, 4
  %17 = icmp eq i64 %16, 0
  %18 = add nsw i64 %12, -2
  %19 = ashr exact i64 %18, 1
  br i1 %15, label %20, label %70

20:                                               ; preds = %8
  %21 = or disjoint i64 %18, 1
  %22 = getelementptr inbounds nuw i32, ptr %5, i64 %21
  %23 = getelementptr inbounds i32, ptr %5, i64 %19
  br label %24

24:                                               ; preds = %20, %64
  %25 = phi ptr [ %65, %64 ], [ %6, %20 ]
  %26 = load i32, ptr %25, align 4, !tbaa !4
  %27 = load i32, ptr %5, align 4, !tbaa !4
  %28 = icmp slt i32 %26, %27
  br i1 %28, label %29, label %64

29:                                               ; preds = %24
  store i32 %27, ptr %25, align 4, !tbaa !4
  br label %30

30:                                               ; preds = %29, %30
  %31 = phi i64 [ %40, %30 ], [ 0, %29 ]
  %32 = shl i64 %31, 1
  %33 = add i64 %32, 2
  %34 = getelementptr inbounds i32, ptr %5, i64 %33
  %35 = or disjoint i64 %32, 1
  %36 = getelementptr inbounds i32, ptr %5, i64 %35
  %37 = load i32, ptr %34, align 4, !tbaa !4
  %38 = load i32, ptr %36, align 4, !tbaa !4
  %39 = icmp slt i32 %37, %38
  %40 = select i1 %39, i64 %35, i64 %33
  %41 = getelementptr inbounds i32, ptr %5, i64 %40
  %42 = load i32, ptr %41, align 4, !tbaa !4
  %43 = getelementptr inbounds i32, ptr %5, i64 %31
  store i32 %42, ptr %43, align 4, !tbaa !4
  %44 = icmp slt i64 %40, %14
  br i1 %44, label %30, label %67, !llvm.loop !16

45:                                               ; preds = %67
  %46 = icmp eq i64 %40, 0
  br i1 %46, label %61, label %49

47:                                               ; preds = %67
  %48 = load i32, ptr %22, align 4, !tbaa !4
  store i32 %48, ptr %23, align 4, !tbaa !4
  br label %49

49:                                               ; preds = %47, %45
  %50 = phi i64 [ %40, %45 ], [ %21, %47 ]
  br label %51

51:                                               ; preds = %49, %58
  %52 = phi i64 [ %54, %58 ], [ %50, %49 ]
  %53 = add nsw i64 %52, -1
  %54 = lshr i64 %53, 1
  %55 = getelementptr inbounds nuw i32, ptr %5, i64 %54
  %56 = load i32, ptr %55, align 4, !tbaa !4
  %57 = icmp slt i32 %56, %26
  br i1 %57, label %58, label %61

58:                                               ; preds = %51
  %59 = getelementptr inbounds i32, ptr %5, i64 %52
  store i32 %56, ptr %59, align 4, !tbaa !4
  %60 = icmp ult i64 %53, 2
  br i1 %60, label %61, label %51, !llvm.loop !17

61:                                               ; preds = %51, %58, %45
  %62 = phi i64 [ 0, %45 ], [ %52, %51 ], [ 0, %58 ]
  %63 = getelementptr inbounds i32, ptr %5, i64 %62
  store i32 %26, ptr %63, align 4, !tbaa !4
  br label %64

64:                                               ; preds = %61, %24
  %65 = getelementptr inbounds nuw i8, ptr %25, i64 4
  %66 = icmp ult ptr %65, %2
  br i1 %66, label %24, label %101, !llvm.loop !26

67:                                               ; preds = %30
  %68 = icmp eq i64 %40, %19
  %69 = select i1 %17, i1 %68, i1 false
  br i1 %69, label %47, label %45

70:                                               ; preds = %8
  %71 = getelementptr inbounds nuw i8, ptr %5, i64 4
  br i1 %17, label %74, label %72

72:                                               ; preds = %70
  %73 = load i32, ptr %5, align 4, !tbaa !4
  br label %102

74:                                               ; preds = %70
  %75 = icmp eq i64 %18, 0
  br i1 %75, label %78, label %76

76:                                               ; preds = %74
  %77 = load i32, ptr %5, align 4, !tbaa !4
  br label %91

78:                                               ; preds = %74, %88
  %79 = phi ptr [ %89, %88 ], [ %6, %74 ]
  %80 = load i32, ptr %79, align 4, !tbaa !4
  %81 = load i32, ptr %5, align 4, !tbaa !4
  %82 = icmp slt i32 %80, %81
  br i1 %82, label %83, label %88

83:                                               ; preds = %78
  store i32 %81, ptr %79, align 4, !tbaa !4
  %84 = load i32, ptr %71, align 4, !tbaa !4
  store i32 %84, ptr %5, align 4, !tbaa !4
  %85 = icmp sge i32 %84, %80
  %86 = zext i1 %85 to i64
  %87 = getelementptr inbounds nuw i32, ptr %5, i64 %86
  store i32 %80, ptr %87, align 4, !tbaa !4
  br label %88

88:                                               ; preds = %83, %78
  %89 = getelementptr inbounds nuw i8, ptr %79, i64 4
  %90 = icmp ult ptr %89, %2
  br i1 %90, label %78, label %101, !llvm.loop !26

91:                                               ; preds = %76, %97
  %92 = phi i32 [ %98, %97 ], [ %77, %76 ]
  %93 = phi ptr [ %99, %97 ], [ %6, %76 ]
  %94 = load i32, ptr %93, align 4, !tbaa !4
  %95 = icmp slt i32 %94, %92
  br i1 %95, label %96, label %97

96:                                               ; preds = %91
  store i32 %92, ptr %93, align 4, !tbaa !4
  store i32 %94, ptr %5, align 4, !tbaa !4
  br label %97

97:                                               ; preds = %96, %91
  %98 = phi i32 [ %94, %96 ], [ %92, %91 ]
  %99 = getelementptr inbounds nuw i8, ptr %93, i64 4
  %100 = icmp ult ptr %99, %2
  br i1 %100, label %91, label %101, !llvm.loop !26

101:                                              ; preds = %108, %97, %88, %64, %3
  ret void

102:                                              ; preds = %72, %108
  %103 = phi i32 [ %109, %108 ], [ %73, %72 ]
  %104 = phi ptr [ %110, %108 ], [ %6, %72 ]
  %105 = load i32, ptr %104, align 4, !tbaa !4
  %106 = icmp slt i32 %105, %103
  br i1 %106, label %107, label %108

107:                                              ; preds = %102
  store i32 %103, ptr %104, align 4, !tbaa !4
  store i32 %105, ptr %5, align 4, !tbaa !4
  br label %108

108:                                              ; preds = %102, %107
  %109 = phi i32 [ %103, %102 ], [ %105, %107 ]
  %110 = getelementptr inbounds nuw i8, ptr %104, i64 4
  %111 = icmp ult ptr %110, %2
  br i1 %111, label %102, label %101, !llvm.loop !26
}

; Function Attrs: mustprogress nounwind uwtable
define linkonce_odr void @_ZSt11__make_heapIN9__gnu_cxx17__normal_iteratorIPiSt6vectorIiSaIiEEEENS0_5__ops15_Iter_less_iterEEvT_S9_RT0_(ptr %0, ptr %1, ptr noundef nonnull align 1 dereferenceable(1) %2) local_unnamed_addr #0 comdat {
  %4 = freeze ptr %0
  %5 = freeze ptr %1
  %6 = ptrtoint ptr %5 to i64
  %7 = ptrtoint ptr %4 to i64
  %8 = sub i64 %6, %7
  %9 = ashr exact i64 %8, 2
  %10 = icmp slt i64 %9, 2
  br i1 %10, label %103, label %11

11:                                               ; preds = %3
  %12 = add nsw i64 %9, -2
  %13 = lshr i64 %12, 1
  %14 = add nsw i64 %9, -1
  %15 = lshr i64 %14, 1
  %16 = and i64 %8, 4
  %17 = icmp eq i64 %16, 0
  %18 = lshr exact i64 %12, 1
  br i1 %17, label %19, label %23

19:                                               ; preds = %11
  %20 = or disjoint i64 %12, 1
  %21 = getelementptr inbounds nuw i32, ptr %4, i64 %20
  %22 = getelementptr inbounds nuw i32, ptr %4, i64 %18
  br label %60

23:                                               ; preds = %11, %55
  %24 = phi i64 [ %59, %55 ], [ %13, %11 ]
  %25 = getelementptr inbounds i32, ptr %4, i64 %24
  %26 = load i32, ptr %25, align 4, !tbaa !4
  %27 = icmp slt i64 %24, %15
  br i1 %27, label %28, label %55

28:                                               ; preds = %23, %28
  %29 = phi i64 [ %38, %28 ], [ %24, %23 ]
  %30 = shl i64 %29, 1
  %31 = add i64 %30, 2
  %32 = getelementptr inbounds i32, ptr %4, i64 %31
  %33 = or disjoint i64 %30, 1
  %34 = getelementptr inbounds i32, ptr %4, i64 %33
  %35 = load i32, ptr %32, align 4, !tbaa !4
  %36 = load i32, ptr %34, align 4, !tbaa !4
  %37 = icmp slt i32 %35, %36
  %38 = select i1 %37, i64 %33, i64 %31
  %39 = getelementptr inbounds i32, ptr %4, i64 %38
  %40 = load i32, ptr %39, align 4, !tbaa !4
  %41 = getelementptr inbounds i32, ptr %4, i64 %29
  store i32 %40, ptr %41, align 4, !tbaa !4
  %42 = icmp slt i64 %38, %15
  br i1 %42, label %28, label %43, !llvm.loop !16

43:                                               ; preds = %28
  %44 = icmp sgt i64 %38, %24
  br i1 %44, label %45, label %55

45:                                               ; preds = %43, %52
  %46 = phi i64 [ %48, %52 ], [ %38, %43 ]
  %47 = add nsw i64 %46, -1
  %48 = sdiv i64 %47, 2
  %49 = getelementptr inbounds nuw i32, ptr %4, i64 %48
  %50 = load i32, ptr %49, align 4, !tbaa !4
  %51 = icmp slt i32 %50, %26
  br i1 %51, label %52, label %55

52:                                               ; preds = %45
  %53 = getelementptr inbounds nuw i32, ptr %4, i64 %46
  store i32 %50, ptr %53, align 4, !tbaa !4
  %54 = icmp sgt i64 %48, %24
  br i1 %54, label %45, label %55, !llvm.loop !17

55:                                               ; preds = %45, %52, %23, %43
  %56 = phi i64 [ %38, %43 ], [ %24, %23 ], [ %48, %52 ], [ %46, %45 ]
  %57 = getelementptr inbounds nuw i32, ptr %4, i64 %56
  store i32 %26, ptr %57, align 4, !tbaa !4
  %58 = icmp eq i64 %24, 0
  %59 = add nsw i64 %24, -1
  br i1 %58, label %103, label %23, !llvm.loop !27

60:                                               ; preds = %19, %98
  %61 = phi i64 [ %102, %98 ], [ %13, %19 ]
  %62 = getelementptr inbounds i32, ptr %4, i64 %61
  %63 = load i32, ptr %62, align 4, !tbaa !4
  %64 = icmp slt i64 %61, %15
  br i1 %64, label %65, label %80

65:                                               ; preds = %60, %65
  %66 = phi i64 [ %75, %65 ], [ %61, %60 ]
  %67 = shl i64 %66, 1
  %68 = add i64 %67, 2
  %69 = getelementptr inbounds i32, ptr %4, i64 %68
  %70 = or disjoint i64 %67, 1
  %71 = getelementptr inbounds i32, ptr %4, i64 %70
  %72 = load i32, ptr %69, align 4, !tbaa !4
  %73 = load i32, ptr %71, align 4, !tbaa !4
  %74 = icmp slt i32 %72, %73
  %75 = select i1 %74, i64 %70, i64 %68
  %76 = getelementptr inbounds i32, ptr %4, i64 %75
  %77 = load i32, ptr %76, align 4, !tbaa !4
  %78 = getelementptr inbounds i32, ptr %4, i64 %66
  store i32 %77, ptr %78, align 4, !tbaa !4
  %79 = icmp slt i64 %75, %15
  br i1 %79, label %65, label %80, !llvm.loop !16

80:                                               ; preds = %65, %60
  %81 = phi i64 [ %61, %60 ], [ %75, %65 ]
  %82 = icmp eq i64 %81, %18
  br i1 %82, label %83, label %85

83:                                               ; preds = %80
  %84 = load i32, ptr %21, align 4, !tbaa !4
  store i32 %84, ptr %22, align 4, !tbaa !4
  br label %85

85:                                               ; preds = %83, %80
  %86 = phi i64 [ %20, %83 ], [ %81, %80 ]
  %87 = icmp sgt i64 %86, %61
  br i1 %87, label %88, label %98

88:                                               ; preds = %85, %95
  %89 = phi i64 [ %91, %95 ], [ %86, %85 ]
  %90 = add nsw i64 %89, -1
  %91 = sdiv i64 %90, 2
  %92 = getelementptr inbounds nuw i32, ptr %4, i64 %91
  %93 = load i32, ptr %92, align 4, !tbaa !4
  %94 = icmp slt i32 %93, %63
  br i1 %94, label %95, label %98

95:                                               ; preds = %88
  %96 = getelementptr inbounds nuw i32, ptr %4, i64 %89
  store i32 %93, ptr %96, align 4, !tbaa !4
  %97 = icmp sgt i64 %91, %61
  br i1 %97, label %88, label %98, !llvm.loop !17

98:                                               ; preds = %88, %95, %85
  %99 = phi i64 [ %86, %85 ], [ %91, %95 ], [ %89, %88 ]
  %100 = getelementptr inbounds nuw i32, ptr %4, i64 %99
  store i32 %63, ptr %100, align 4, !tbaa !4
  %101 = icmp eq i64 %61, 0
  %102 = add nsw i64 %61, -1
  br i1 %101, label %103, label %60, !llvm.loop !27

103:                                              ; preds = %55, %98, %3
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.ctlz.i64(i64, i1 immarg) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smax.i32(i32, i32) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write)
declare void @llvm.assume(i1 noundef) #7

attributes #0 = { mustprogress nounwind uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #3 = { mustprogress nocallback nofree nounwind willreturn memory(errnomem: write) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #5 = { nobuiltin allocsize(0) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #6 = { nobuiltin nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #7 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write) }
attributes #8 = { builtin nounwind allocsize(0) }
attributes #9 = { nounwind }
attributes #10 = { builtin nounwind }

!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 2}
!3 = !{!"Ubuntu clang version 22.0.0 (++20251015042503+856555bfd843-1~exp1~20251015042630.2731)"}
!4 = !{!5, !5, i64 0}
!5 = !{!"int", !6, i64 0}
!6 = !{!"omnipotent char", !7, i64 0}
!7 = !{!"Simple C++ TBAA"}
!8 = !{!9, !9, i64 0}
!9 = !{!"float", !6, i64 0}
!10 = distinct !{!10, !11}
!11 = !{!"llvm.loop.unroll.disable"}
!12 = distinct !{!12, !13}
!13 = !{!"llvm.loop.mustprogress"}
!14 = distinct !{!14, !13}
!15 = distinct !{!15, !11}
!16 = distinct !{!16, !13}
!17 = distinct !{!17, !13}
!18 = distinct !{!18, !13}
!19 = distinct !{!19, !13}
!20 = distinct !{!20, !13}
!21 = distinct !{!21, !13}
!22 = distinct !{!22, !13}
!23 = distinct !{!23, !13}
!24 = distinct !{!24, !13}
!25 = distinct !{!25, !13}
!26 = distinct !{!26, !13}
!27 = distinct !{!27, !13}
