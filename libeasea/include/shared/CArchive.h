/***********************************************************************
| CArchive.h	                                                        |
|                                                                       |
| This file is part of Artificial Evolution plateform EASEA             |
| (EAsy Specification of Evolutionary Algorithms)                       |
| https://github.com/EASEA/                                             |
|                                                                       |
| Copyright (c)                                                         |
| ICUBE Strasbourg                                                      |
| Date: 2019-05                                                         |
|                                                                       |
 ***********************************************************************/
#pragma once

#include <cstddef>
#include <vector>
#include <shared/CConstant.h>

#include <shared/functions/crowdingDistance.h>
#include <shared/functions/dominance.h>
namespace easea
{
namespace shared
{
/*
 * brief Class of archive population
 * param[in] TIndividual - type of individual
 */

template <typename TIndividual>
class CArchive
{
public:
        typedef TIndividual TI;
	typedef typename TI::TO TO;
        typedef std::vector<TI> TArchive;

        CArchive(const size_t size);
        ~CArchive(void);
//        TArchive &getArchive(void);
        bool isEmpty();
	void updateArchive(const TI candidate);
	static bool Dominate(const TI &individual1, const TI &individual2);

protected:
	TArchive m_archive;
	static bool isDominated(const TI *individual1, const TI *individual2);

private:
	size_t	 m_maxSize;
};


template <typename TIndividual>
CArchive<TIndividual>::CArchive(const size_t size)
	: m_maxSize(size)
{
        if (size <= 0 ) LOG_FATAL("Wrong size of archive! Pleace, check it");
}
        
template <typename TIndividual>
CArchive<TIndividual>::~CArchive(void)
{
}

template <typename TIndividual>
bool CArchive<TIndividual>::isEmpty()
{
	if (m_archive.size() < 0) LOG_FATAL("Size of archive < 0!");
	
	return m_archive.empty();
}

template <typename TIndividual>
bool CArchive<TIndividual>::Dominate(const TI &individual1, const TI &individual2)
{
        return easea::shared::functions::isDominated(individual1.m_objective, individual2.m_objective);
}

template <typename TIndividual>
bool CArchive<TIndividual>::isDominated(const TI *individual1, const TI *individual2)
{
        return Dominate(*individual1, *individual2);
}

template <typename TIndividual>
void CArchive<TIndividual>::updateArchive(const TI candidate) 
{ 
	if (m_archive.size() < 0) LOG_FATAL("Size of archive < 0!");

	for (auto it = m_archive.begin(); it != m_archive.end();)
	{
		if (Dominate(candidate, *it))
			it = m_archive.erase(it);
		else if (Dominate(*it, candidate))
			return;
		else	++it;
	}
	m_archive.push_back(candidate);
	if (m_archive.size() >  m_maxSize)
	{
		typedef typename TArchive::pointer TPtr;
		std::list<TPtr> arch;

		for (size_t i = 0; i < m_archive.size(); ++i)
    			arch.push_back(&m_archive[i]);
		std::vector<TPtr> iFront(arch.begin(), arch.end());
		easea::shared::functions::setCrowdingDistance< TO>(iFront.begin(), iFront.end());

    		std::sort(iFront.begin(), iFront.end(), [](TPtr individual1, TPtr individual2)->bool{return individual1->m_crowdingDistance > individual2->m_crowdingDistance;});
		m_archive.erase(m_archive.end());
	}

}
}
}