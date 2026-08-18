#pragma once

#include "Containers.hpp"

typedef float /* double */ fpoint; // use double if the game uses Unreal Engine 5 or above

struct FVector
{
public:
    fpoint X;
    fpoint Y;
    fpoint Z;

public:
    FVector() : X(0), Y(0), Z(0) {}
    FVector(fpoint v) : X(v), Y(v), Z(v) {}
    FVector(fpoint x, fpoint y, fpoint z) : X(x), Y(y), Z(z) {}

    FVector Normalize()
    {
        *this /= Magnitude();
        return *this;
    }

    FVector operator*=(const FVector& Other)
    {
        *this = *this * Other;
        return *this;
    }

    FVector operator*=(fpoint Scalar)
    {
        *this = *this * Scalar;
        return *this;
    }

    FVector operator+=(const FVector& Other)
    {
        *this = *this + Other;
        return *this;
    }

    FVector operator-=(const FVector& Other)
    {
        *this = *this - Other;
        return *this;
    }

    FVector operator/=(const FVector& Other)
    {
        *this = *this / Other;
        return *this;
    }

    FVector operator/=(fpoint Scalar)
    {
        *this = *this / Scalar;
        return *this;
    }

    fpoint Dot(const FVector& Other) const
    {
        return (X * Other.X) + (Y * Other.Y) + (Z * Other.Z);
    }

    fpoint GetDistanceTo(const FVector& Other) const
    {
        FVector DiffVector = Other - *this;
        return DiffVector.Magnitude();
    }

    fpoint GetDistanceToInMeters(const FVector& Other) const
    {
        return GetDistanceTo(Other) * 0.01;
    }

    bool IsNearlyZero(fpoint Tolerance = 1.e-4f) const
    {
        return SizeSquared() <= Tolerance * Tolerance;
    }

    FVector GetNormalized() const
    {
        return *this / Magnitude();
    }

    fpoint SizeSquared() const
    {
        return X * X + Y * Y + Z * Z;
    }

    FVector GetSafeNormal(fpoint Tolerance = 1.e-8f) const
    {
        const fpoint SquareSum = X*X + Y*Y + Z*Z;
        if (SquareSum == 1.f)
            return *this;	
        else if (SquareSum < Tolerance)
            return FVector();
        
        const fpoint Scale = 1.0f / std::sqrt(SquareSum);
        return FVector(X*Scale, Y*Scale, Z*Scale);
    }

    bool IsZero() const
    {
        return X == 0.0 && Y == 0.0 && Z == 0.0;
    }

    fpoint Magnitude() const
    {
        return std::sqrt((X * X) + (Y * Y) + (Z * Z));
    }

    bool operator!=(const FVector& Other) const
    {
        return X != Other.X || Y != Other.Y || Z != Other.Z;
    }

    FVector operator*(const FVector& Other) const
    {
        return {X * Other.X, Y * Other.Y, Z * Other.Z};
    }

    FVector operator*(fpoint Scalar) const
    {
        return {X * Scalar, Y * Scalar, Z * Scalar};
    }

    FVector operator+(const FVector& Other) const
    {
        return {X + Other.X, Y + Other.Y, Z + Other.Z};
    }

    FVector operator-(const FVector& Other) const
    {
        return {X - Other.X, Y - Other.Y, Z - Other.Z};
    }

    FVector operator/(const FVector& Other) const
    {
        return {X / Other.X, Y / Other.Y, Z / Other.Z};
    }

    FVector operator/(fpoint Scalar) const
    {
        return {X / Scalar, Y / Scalar, Z / Scalar};
    }

    bool operator==(const FVector& Other) const
    {
        return X == Other.X && Y == Other.Y && Z == Other.Z;
    }

    FVector operator^(const FVector& V) const
    {
        return FVector(Y * V.Z - Z * V.Y, Z * V.X - X * V.Z, X * V.Y - Y * V.X);
    }

    fpoint operator|(const FVector& V) const
    {
        return X * V.X + Y * V.Y + Z * V.Z;
    }

    static FVector CrossProduct(const FVector& A, const FVector& B)
    {
        return A ^ B;
    }

    FORCEINLINE operator ImVec3() const
    {
        return ImVec3(X, Y, Z);
    }

    static FVector Zero;
};

struct FVector2D final
{
public: 
	fpoint X; 
	fpoint Y;

public:
	FVector2D() : X(0), Y(0) {}
	FVector2D(fpoint v) : X(), Y(v) {}
	FVector2D(fpoint x, fpoint y) : X(x), Y(y) {}

    FORCEINLINE operator ImVec2() const
    {
        return ImVec2(X, Y);
    }

	FVector2D& operator*=(const FVector2D& Other)
	{
        *this = *this * Other;
        return *this;
    }

	FVector2D& operator*=(fpoint Scalar)
	{
        *this = *this * Scalar;
        return *this;
    }

	FVector2D& operator+=(const FVector2D& Other)
	{
        *this = *this + Other;
        return *this;
    }

	FVector2D& operator-=(const FVector2D& Other)
	{
        *this = *this - Other;
        return *this;
    }

	FVector2D& operator/=(const FVector2D& Other)
	{
        *this = *this / Other;
        return *this;
    }

	FVector2D& operator/=(fpoint Scalar)
	{
        *this = *this / Scalar;
        return *this;
    }

    fpoint GetDistanceTo(const FVector2D& Other) const
    {
        FVector2D DiffVector = Other - *this;
        return DiffVector.Magnitude();
    }

    static fpoint GetDistance(const FVector2D& A, const FVector2D& B)
    {
        return A.GetDistanceTo(B);
    }

    fpoint GetDistanceToInMeters(const FVector2D& Other) const
    {
        return GetDistanceTo(Other) * 0.01;
    }

    FVector2D GetNormalized() const
    {
        return *this / Magnitude();
    }

    bool IsZero() const
    {
        return X == 0.0 && Y == 0.0;
    }

    fpoint Magnitude() const
    {
        return std::sqrt((X * X) + (Y * Y));
    }

	bool operator!=(const FVector2D& Other) const
	{
        return X != Other.X || Y != Other.Y;
    }

	FVector2D operator*(const FVector2D& Other) const
	{
        return {X * Other.X, Y * Other.Y};
    }

	FVector2D operator*(fpoint Scalar) const
	{
        return {X * Scalar, Y * Scalar};
    }

	FVector2D operator+(const FVector2D& Other) const
	{
        return {X + Other.X, Y + Other.Y};
    }

	FVector2D operator-(const FVector2D& Other) const
	{
        return {X - Other.X, Y - Other.Y};
    }

	FVector2D operator/(const FVector2D& Other) const
	{
        return {X / Other.X, Y / Other.Y};
    }

	FVector2D operator/(fpoint Scalar) const
	{
        return {X / Scalar, Y / Scalar};
    }

	bool operator==(const FVector2D& Other) const
	{
        return X == Other.X && Y == Other.Y;
    }

    static FVector2D Zero;
};

struct FQuat final
{
    fpoint X, Y, Z, W; 

    FVector operator*(const FVector& V) const
    {
        return RotateVector(V);
    }

    FVector RotateVector(const FVector& V) const
    {
        // http://people.csail.mit.edu/bkph/articles/Quaternions.pdf
        // V' = V + 2w(Q x V) + (2Q x (Q x V))
        // refactor:
        // V' = V + w(2(Q x V)) + (Q x (2(Q x V)))
        // T = 2(Q x V);
        // V' = V + w*(T) + (Q x T)

        const FVector Q(X, Y, Z);
        const FVector T = FVector::CrossProduct(Q, V) * 2.0f;
        return V + (T * W) + FVector::CrossProduct(Q, T);
    }
};

struct FPlane 
{
    fpoint X, Y, Z, W;

    FPlane() = default;
    FPlane(fpoint _X, fpoint _Y, fpoint _Z, fpoint _W) : X(_X), Y(_Y), Z(_Z), W(_W) {}
};

struct FMatrix final
{
    union
    {
        struct
        {
            FPlane XPlane;
            FPlane YPlane;
            FPlane ZPlane;
            FPlane WPlane;
        };
        fpoint M[4][4];
    };

    FMatrix() = default;
    FMatrix(FPlane X, FPlane Y, FPlane Z, FPlane W) : XPlane(X), YPlane(Y), ZPlane(Z), WPlane(W) {}
    
    fpoint *operator[](int Index) 
    {
        return M[Index];
    }

    const fpoint* operator[](int Index) const 
    {
        return M[Index];
    }

    FMatrix operator*(const FMatrix& other)
    {
        FMatrix Ret;
        for (int i = 0; i < 4; i++)
        {
            for (int j = 0; j < 4; j++)
            {
                for (int k = 0; k < 4; k++)
                {
                    Ret.M[i][j] += M[i][k] * other.M[k][j];
                }
            }
        }
        return Ret;
    }

    FVector GetOrigin() const
    {
        return FVector(M[3][0], M[3][1], M[3][2]);
    }

    static FMatrix Identity;
};

struct FRotator final
{
    fpoint Pitch, Yaw, Roll;

    FRotator() = default;
    FRotator(fpoint _Pitch, fpoint _Yaw, fpoint _Roll = 0.0f) : Pitch(_Pitch), Yaw(_Yaw), Roll(_Roll) {}

    FVector Vector() const
    {
        fpoint PitchNoWinding = std::fmod(Pitch, 360.0f);
        fpoint YawNoWinding = std::fmod(Yaw, 360.0f);

        const fpoint RadPitch = PitchNoWinding * (M_PI / 180.0f);
        const fpoint RadYaw = YawNoWinding * (M_PI / 180.0f);

        fpoint SP = std::sin(RadPitch);
        fpoint CP = std::cos(RadPitch);
        fpoint SY = std::sin(RadYaw);
        fpoint CY = std::cos(RadYaw);

        return FVector(CP * CY, CP * SY, SP);
    }

    FMatrix ToMatrix() const
    {
        fpoint radPitch = Pitch * ((fpoint)M_PI / 180.0f);
        fpoint radYaw   = Yaw   * ((fpoint)M_PI / 180.0f);
        fpoint radRoll  = Roll  * ((fpoint)M_PI / 180.0f);
        
        fpoint SP = std::sin(radPitch);
        fpoint CP = std::cos(radPitch);
        fpoint SY = std::sin(radYaw);
        fpoint CY = std::cos(radYaw);
        fpoint SR = std::sin(radRoll);
        fpoint CR = std::cos(radRoll);
        
        FMatrix Ret;
        
        Ret.M[0][0] = (CP * CY);
        Ret.M[0][1] = (CP * SY);
        Ret.M[0][2] = (SP);
        Ret.M[0][3] = 0;
        
        Ret.M[1][0] = (SR * SP * CY - CR * SY);
        Ret.M[1][1] = (SR * SP * SY + CR * CY);
        Ret.M[1][2] = (-SR * CP);
        Ret.M[1][3] = 0;
        
        Ret.M[2][0] = (-(CR * SP * CY + SR * SY));
        Ret.M[2][1] = (CY * SR - CR * SP * SY);
        Ret.M[2][2] = (CR * CP);
        Ret.M[2][3] = 0;
        
        Ret.M[3][0] = 0;
        Ret.M[3][1] = 0;
        Ret.M[3][2] = 0;
        Ret.M[3][3] = 1;

        return Ret;
    }
};

struct FTransform final
{
    // Dependant on game and its padding alignment
    // Add the paddings that are dumped
    FQuat Rotation;
    FVector Translation;
    FVector Scale3D;
    uint8 Pad[0x8];
    
    
    inline FMatrix ToMatrixWithScale() const
	{
		FMatrix OutMatrix;

		OutMatrix.M[3][0] = Translation.X;
		OutMatrix.M[3][1] = Translation.Y;
		OutMatrix.M[3][2] = Translation.Z;

		const fpoint x2 = Rotation.X + Rotation.X;
		const fpoint y2 = Rotation.Y + Rotation.Y;
		const fpoint z2 = Rotation.Z + Rotation.Z;
		{
			const fpoint xx2 = Rotation.X * x2;
			const fpoint yy2 = Rotation.Y * y2;
			const fpoint zz2 = Rotation.Z * z2;

			OutMatrix.M[0][0] = (1.0f - (yy2 + zz2)) * Scale3D.X;
			OutMatrix.M[1][1] = (1.0f - (xx2 + zz2)) * Scale3D.Y;
			OutMatrix.M[2][2] = (1.0f - (xx2 + yy2)) * Scale3D.Z;
		}
		{
			const fpoint yz2 = Rotation.Y * z2;
			const fpoint wx2 = Rotation.W * x2;

			OutMatrix.M[2][1] = (yz2 - wx2) * Scale3D.Z;
			OutMatrix.M[1][2] = (yz2 + wx2) * Scale3D.Y;
		}
		{
			const fpoint xy2 = Rotation.X * y2;
			const fpoint wz2 = Rotation.W * z2;

			OutMatrix.M[1][0] = (xy2 - wz2) * Scale3D.Y;
			OutMatrix.M[0][1] = (xy2 + wz2) * Scale3D.X;
		}
		{
			const fpoint xz2 = Rotation.X * z2;
			const fpoint wy2 = Rotation.W * y2;

			OutMatrix.M[2][0] = (xz2 + wy2) * Scale3D.Z;
			OutMatrix.M[0][2] = (xz2 - wy2) * Scale3D.X;
		}

		OutMatrix.M[0][3] = 0.0f;
		OutMatrix.M[1][3] = 0.0f;
		OutMatrix.M[2][3] = 0.0f;
		OutMatrix.M[3][3] = 1.0f;

		return OutMatrix;
	}

    inline FMatrix ToMatrixNoScale() const
	{
		FMatrix OutMatrix;

		OutMatrix.M[3][0] = Translation.X;
		OutMatrix.M[3][1] = Translation.Y;
		OutMatrix.M[3][2] = Translation.Z;

		const fpoint x2 = Rotation.X + Rotation.X;
		const fpoint y2 = Rotation.Y + Rotation.Y;
		const fpoint z2 = Rotation.Z + Rotation.Z;
		{
			const fpoint xx2 = Rotation.X * x2;
			const fpoint yy2 = Rotation.Y * y2;
			const fpoint zz2 = Rotation.Z * z2;

			OutMatrix.M[0][0] = (1.0f - (yy2 + zz2));
			OutMatrix.M[1][1] = (1.0f - (xx2 + zz2));
			OutMatrix.M[2][2] = (1.0f - (xx2 + yy2));
		}
		{
			const fpoint yz2 = Rotation.Y * z2;
			const fpoint wx2 = Rotation.W * x2;

			OutMatrix.M[2][1] = (yz2 - wx2);
			OutMatrix.M[1][2] = (yz2 + wx2);
		}
		{
			const fpoint xy2 = Rotation.X * y2;
			const fpoint wz2 = Rotation.W * z2;

			OutMatrix.M[1][0] = (xy2 - wz2);
			OutMatrix.M[0][1] = (xy2 + wz2);
		}
		{
			const fpoint xz2 = Rotation.X * z2;
			const fpoint wy2 = Rotation.W * y2;

			OutMatrix.M[2][0] = (xz2 + wy2);
			OutMatrix.M[0][2] = (xz2 - wy2);
		}

		OutMatrix.M[0][3] = 0.0f;
		OutMatrix.M[1][3] = 0.0f;
		OutMatrix.M[2][3] = 0.0f;
		OutMatrix.M[3][3] = 1.0f;

		return OutMatrix;
	}

    FVector operator*(const FTransform& Other) const
    {
        return Other.Rotation * (Other.Scale3D * Translation) + Other.Translation;
    }

    FVector GetLocation() const
    {
        return Translation;
    }
};



class FText final
{
public:
    void* TextData;
    uint8 Pad[0x10];

private:

    struct FTextDisplayStringPtr 
    {
        FString* Object;
        void* SharedReferenceCount;
    };

    static inline const FString& (*GetDisplayString_Internal)(void* _this) = nullptr;
    static inline FTextDisplayStringPtr (*GetLocalizedString_Internal)(void* _this) = nullptr;
public:

    const FString& GetDisplayString() const
    {
        void** VTable = *reinterpret_cast<void***>(TextData);
        GetDisplayString_Internal = (const FString&(*)(void*))(VTable[3]);
        return GetDisplayString_Internal(TextData);
    }

    FString* GetLocalizedString() const
    {
        void** VTable = *reinterpret_cast<void***>(TextData);
        GetLocalizedString_Internal = (FTextDisplayStringPtr(*)(void*))(VTable[4]);
        return GetLocalizedString_Internal(TextData).Object;
    }

    std::string ToString() const
    {
        if ( TextData )
        {
            return GetDisplayString().ToString();
        }
        return "";
    }

    std::u16string ToWString() const
    {
        if ( TextData )
        {
            return GetDisplayString().ToWString();
        }
        return u"";
    }
};

struct FLinearColor 
{
    fpoint R, G, B, A;

    FLinearColor() = default;
    FLinearColor(fpoint r, fpoint g, fpoint b, fpoint a = 1.0f) : R(r), G(g), B(b), A(a) {}
};

