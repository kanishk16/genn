#include "currentSourceModels.h"

// Implement models
IMPLEMENT_MODEL(CurrentSourceModels::DC);
IMPLEMENT_MODEL(CurrentSourceModels::GaussianNoise);
IMPLEMENT_MODEL(CurrentSourceModels::PoissonExp);

//----------------------------------------------------------------------------
// CurrentSourceModels::Base
//----------------------------------------------------------------------------
bool CurrentSourceModels::Base::canBeMerged(const Base *other) const
{
    return (Models::Base::canBeMerged(other)
            && (getInjectionCode() == other->getInjectionCode()));
}
