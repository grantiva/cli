package com.kylebrowning.landmarks.data

import com.kylebrowning.landmarks.TestEnvironment

object SampleData {
    private fun landmark(
        name: String,
        location: String,
        category: Category,
        featured: Boolean = false,
        description: String,
    ) = Landmark(Landmark.slug(name), name, location, description, featured, category)

    val contract: List<Landmark> = listOf(
        landmark("Golden Gate Bridge", "San Francisco, CA", Category.BRIDGES, true,
            "A suspension bridge spanning the Golden Gate strait."),
        landmark("Lake Tahoe", "Sierra Nevada, CA", Category.LAKES,
            description = "A large freshwater lake in the Sierra Nevada."),
        landmark("Half Dome", "Yosemite, CA", Category.MOUNTAINS, true,
            "A granite dome at the eastern end of Yosemite Valley."),
        landmark("Yosemite Valley", "Yosemite, CA", Category.MOUNTAINS,
            description = "A glacial valley in Yosemite National Park."),
        landmark("Bixby Creek Bridge", "Big Sur, CA", Category.BRIDGES,
            description = "A reinforced concrete arch bridge on the Big Sur coast."),
        landmark("Mono Lake", "Lee Vining, CA", Category.LAKES,
            description = "A saline soda lake known for its tufa towers."),
        landmark("Mount Shasta", "Siskiyou County, CA", Category.MOUNTAINS,
            description = "A potentially active volcano in the Cascade Range."),
        landmark("Crater Lake", "Oregon", Category.LAKES,
            description = "A caldera lake formed by the collapse of Mount Mazama."),
        landmark("Brooklyn Bridge", "New York, NY", Category.BRIDGES,
            description = "A hybrid cable-stayed suspension bridge over the East River."),
        landmark("Mount \"Denali\"", "Alaska", Category.MOUNTAINS,
            description = "The highest mountain peak in North America."),
    )

    fun seeded(seed: TestEnvironment.Seed): List<Landmark> = when (seed) {
        TestEnvironment.Seed.DEFAULT -> contract
        TestEnvironment.Seed.EMPTY -> emptyList()
        TestEnvironment.Seed.MANY -> contract + (11..70).map { n ->
            val cycle = listOf(Category.MOUNTAINS, Category.LAKES, Category.BRIDGES)
            landmark("Landmark $n", "Nowhere, CA", cycle[(n - 11) % 3],
                description = "Generated landmark number $n.")
        }
    }
}
