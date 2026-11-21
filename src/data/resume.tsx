// Everything shown on the homepage comes from this file. Components read from
// `DATA` and should not need to change. Content mirrors the latest release of
// https://github.com/jwallace145/resume.
import { Icons } from "@/components/icons";
import { Archive, BookOpen, Crown, Guitar, House, Library, Mountain, Package } from "lucide-react";
import { Typescript } from "@/components/ui/svgs/typescript";
import { Python } from "@/components/ui/svgs/python";
import { Java } from "@/components/ui/svgs/java";
import { Golang } from "@/components/ui/svgs/golang";
import { Postgresql } from "@/components/ui/svgs/postgresql";
import { Docker } from "@/components/ui/svgs/docker";
import { Kubernetes } from "@/components/ui/svgs/kubernetes";
import { Nodejs } from "@/components/ui/svgs/nodejs";

// Upper bound on a project card's description, enforced by resume.test.ts.
// The cards share a row, so a long description costs vertical space for the
// whole section; a pitch fits in a few sentences.
export const PROJECT_DESCRIPTION_MAX_CHARS = 550;

export const DATA = {
  name: "Jimmy Wallace",
  initials: "JW",
  location: "Denver, CO",
  locationLink: "https://www.google.com/maps/place/Denver,+CO",
  description: "Software engineer w/ a love of math, machine learning, and AI.",
  summary:
    "I'm a software engineer with six years of experience building cloud platforms and backend services. Today I lead DevOps for Data Lake Platforms at [Charter Communications](/#work), where I build serverless AWS services and architect data platforms used across the organization. Before that I owned EC2's metering service at [AWS](/#work) and built container tooling at [Capital One](/#work). On the side I build [JAWS](/#projects), the platform behind everything I run on AWS, and [Braveheart](/#projects), a chess engine in Rust rated about 3,170 Elo. I also built [Prog Strength](/#projects), an AI-native fitness platform with a conversational AI coach, which I've since archived. I studied Computer Science and Engineering at [The Ohio State University](/#education) with a minor in mathematics and a concentration in artificial intelligence.",
  // TODO: replace public/og_image.png with your own image.
  avatarUrl: "/jwall-engineering-avatar.png",
  ogImage: "/og_image.png",
  sections: {
    about: { order: 1, enabled: true, heading: "About" },
    work: { order: 2, enabled: true, heading: "Work Experience", presentLabel: "Present" },
    education: { order: 3, enabled: true, heading: "Education" },
    skills: { order: 4, enabled: true, heading: "Skills" },
    interests: { order: 5, enabled: true, heading: "Hobbies & Interests" },
    projects: {
      order: 6,
      enabled: true,
      label: "My Projects",
      heading: "Check out my latest work",
      text: "Things I build outside of work, mostly at the intersection of AI agents and cloud infrastructure.",
    },
    photos: {
      order: 7,
      enabled: false,
      heading: "Photos",
    },
    hackathons: {
      order: 8,
      enabled: false,
      label: "Hackathons",
      heading: "I like building things",
      text: "TODO: A sentence about hackathons. {count} is replaced with the number of entries.",
    },
    contact: {
      order: 9,
      enabled: true,
      label: "Contact",
      heading: "Get in Touch",
      text: "Want to chat about AI, cloud infrastructure, or any of my projects? Send me a message on LinkedIn or drop me an email and I'll get back to you.",
    },
  },
  // TODO: replace the placeholder photos in public/photos/ or disable the section above.
  photos: [
    { src: "/photos/photo1.jpg", alt: "TODO: describe the photo" },
    { src: "/photos/photo2.jpg", alt: "TODO: describe the photo" },
    { src: "/photos/photo3.jpg", alt: "TODO: describe the photo" },
  ],
  skills: [
    { name: "Java", icon: Java },
    { name: "Python", icon: Python },
    { name: "Go", icon: Golang },
    { name: "TypeScript", icon: Typescript },
    { name: "Node.js", icon: Nodejs },
    { name: "AWS", icon: undefined },
    { name: "Terraform", icon: undefined },
    { name: "Docker", icon: Docker },
    { name: "Kubernetes", icon: Kubernetes },
    { name: "Postgres", icon: Postgresql },
    { name: "Databricks", icon: undefined },
    { name: "MCP", icon: undefined },
  ],
  // A few things outside of engineering. `description` is markdown so it can
  // link out; keep each one to a sentence or two.
  interests: [
    {
      name: "Guitar",
      icon: Guitar,
      description:
        "Over ten years on electric blues guitar and an avid rock and blues fan. John Mayer, Stevie Ray Vaughan, and B.B. King are on heavy rotation.",
    },
    {
      name: "Philosophy",
      icon: BookOpen,
      description:
        "I read philosophy in my spare time and enjoy a good dialogue on society and ethics. Currently reading [The Metamorphosis](https://en.wikipedia.org/wiki/The_Metamorphosis) by [Franz Kafka](https://en.wikipedia.org/wiki/Franz_Kafka).",
    },
    {
      name: "Mountaineering",
      icon: Mountain,
      description:
        "Rock climber and mountaineer. I summit peaks on foot or on rope, and trail run in the mountains whenever I can.",
    },
  ],
  navbar: [
    { href: "/", icon: House, label: "Home" },
    { href: "/blog", icon: Library, label: "Blog" },
  ],
  contact: {
    email: "jimmy.wallace145@gmail.com",
    tel: "",
    social: {
      GitHub: {
        name: "GitHub",
        url: "https://github.com/jwallace145",
        icon: Icons.github,
        navbar: true,
      },
      LinkedIn: {
        name: "LinkedIn",
        url: "https://www.linkedin.com/in/jimmy-wallace-436143149/",
        icon: Icons.linkedin,
        navbar: true,
      },
      email: {
        name: "Send Email",
        url: "mailto:jimmy.wallace145@gmail.com",
        icon: Icons.email,
        navbar: false,
      },
    },
  },

  // Most recent first. Each company lists its roles, most recent first, so a
  // promotion shows as two roles under one logo. `end: undefined` renders as
  // "Present". Bullets are plain strings so the component owns the markup.
  work: [
    {
      company: "Charter Communications",
      href: "https://corporate.charter.com",
      location: "Denver, CO",
      logoUrl: "/logos/charter.svg",
      roles: [
        {
          title: "Lead DevOps Engineer",
          team: "Data Platforms Infrastructure & Solutions - Data Lake Platforms",
          start: "July 2025",
          end: undefined,
          bullets: [
            "Built and deployed the PII Access Auditor, an event-driven serverless AWS service delivering the organization's first real-time alerting, logging, and violation reporting for PII access. A queue-driven Lambda collects and centrally caches IAM and resource permission data across a hub-and-spoke architecture of 50+ accounts, then analyzes access and generates monitoring and reporting at organizational scale.",
            "Architected Charter's Databricks pilot platform on AWS spanning multiple environments to support all workspaces across the organization, engineering VPC isolation, SSO integration, AD-based access control, Unity Catalog data governance, and infrastructure policies and limits to control cloud costs. Integrated existing AWS Glue catalogs to accelerate team onboarding and preserve access to established datasets.",
            "Independently led the cross-enterprise effort between Charter and AWS to resolve a breaking AWS Glue service release that changed IAM permission caching behavior and disrupted Charter's transient role approach, threatening downtime for every EMR reporting team in the organization. Coordinated with AWS to roll back the release and refactored Charter's EMR orchestration layer from dynamic IAM policy swapping to static, team-scoped roles through a monitored rollout across 500+ developers with zero regressions.",
          ],
        },
      ],
    },
    {
      company: "Amazon Web Services (AWS)",
      href: "https://aws.amazon.com",
      location: "Arlington, VA",
      logoUrl: "/logos/aws.svg",
      roles: [
        {
          title: "Software Development Engineer II",
          team: "EC2 Core Platform · EC2 Metering",
          start: "August 2022",
          end: "April 2025",
          bullets: [
            "Owned and improved AWS' Java (JDK 17) metering service for EC2 resources to accurately meter customer instance and host usage globally (single and shared tenancy), as well as other EC2 resources such as On-Demand Capacity Reservations (ODCRs), IP Address Manager (IPAM), and all IPv4 resources (billions of records per day) with a 99.999% metering accuracy SLA.",
            "Independently developed EC2's metering system for AWS Global Accelerator, AWS VPN Site-to-Site Connections, and IPv4 Contiguous Blocks in Java.",
            "Identified and created a simplified onboarding framework to add new EC2 resources to EC2's metering system within a week, decreasing engineering time from three months and saving the team valuable resources.",
            "Promoted internal recyclability of service hosts to help EC2 maximize host pool utilization by developing a metering system to remove discounts for old hosts and avoid host hoarding (billions of records per year).",
          ],
        },
      ],
    },
    {
      company: "Capital One",
      href: "https://www.capitalone.com",
      location: "Richmond, VA",
      logoUrl: "/logos/capital-one.svg",
      roles: [
        {
          title: "Senior Associate Software Engineer",
          team: "Delivery Experience · Containers (ECS Fargate)",
          start: "July 2021",
          end: "August 2022",
          bullets: [
            "Designed and owned an internal enterprise toolchain (Python, Boto3, CloudFormation, Jinja) to deploy and migrate containerized applications to ECS Fargate, streamlining the organization's transition from ECS on EC2.",
          ],
        },
        {
          title: "Associate Software Engineer",
          team: "Commercial Bank · Robotic Process Automation (RPA)",
          start: "August 2020",
          end: "July 2021",
          bullets: [
            "Maintained RPA cloud infrastructure for Commercial Bank (Automation Anywhere on EC2 via ASGs) and improved disaster recovery by migrating bot code storage from EBS to Amazon FSx and implementing cross-region SQL Server backup replication via serverless Lambda functions.",
          ],
        },
      ],
    },
  ],
  // Most recent first.
  education: [
    {
      school: "The Ohio State University",
      href: "https://engineering.osu.edu",
      degree: "B.S. Computer Science and Engineering · Minor in Mathematics, AI concentration",
      logoUrl: "/logos/ohio-state.svg",
      start: "August 2016",
      end: "May 2020",
    },
  ],
  // `image` or `video` is optional.
  projects: [
    {
      title: "JAWS",
      href: "https://github.com/Jaws-Platform",
      dates: "October 2026 - Present",
      active: true,
      description:
        "The platform behind everything I run on AWS: static sites, Lichess bots, research workloads, and Databricks workspaces, each declared in one YAML file in its own repo. A Python CLI (Typer) renders Terraform stacks against a hardened central state bucket, built from seven modules I publish to the Terraform Registry. It ships as a versioned image behind reusable GitHub Actions workflows, so project repos keep no Terraform: plan comments on PRs, per-PR preview URLs, and OIDC-scoped releases come from a few workflow calls.",
      technologies: [
        "Python",
        "Typer",
        "Terraform",
        "AWS",
        "Docker",
        "GitHub Actions",
        "OIDC",
        "Databricks",
      ],
      links: [
        {
          type: "GitHub",
          href: "https://github.com/Jaws-Platform",
          icon: <Icons.github className="size-3" />,
        },
        {
          type: "CLI",
          href: "https://github.com/Jaws-Platform/jaws",
          icon: <Icons.github className="size-3" />,
        },
        {
          type: "Registry",
          href: "https://registry.terraform.io/namespaces/Jaws-Platform",
          icon: <Package className="size-3" />,
        },
      ],
      image: "",
      video: "",
    },
    {
      title: "Braveheart",
      href: "https://github.com/Braveheart-Chess",
      dates: "November 2025 - Present",
      active: true,
      description:
        "A UCI chess engine in Rust: a heavily optimized alpha-beta search paired with an NNUE evaluator trained on 3.2 billion self-play, self-labeled positions I curate in S3 and train on AWS GPUs. Every change must earn its merge: CI benchmarks speed and search efficiency against bars that only rise, and changes ship only after passing SPRT gates for Elo. Rated about 3,170 Elo on a Stockfish-calibrated ladder and live as a Lichess bot on infra from my JAWS platform. Named for the Scotch Opening and my ancestor William Wallace.",
      technologies: ["Rust", "NNUE", "Alpha-Beta Search", "SPRT", "CUDA", "AWS", "GitHub Actions"],
      links: [
        {
          type: "GitHub",
          href: "https://github.com/Braveheart-Chess",
          icon: <Icons.github className="size-3" />,
        },
        {
          type: "Engine",
          href: "https://github.com/Braveheart-Chess/braveheart",
          icon: <Icons.github className="size-3" />,
        },
        {
          type: "Lichess",
          href: "https://lichess.org/@/jwallace145",
          icon: <Crown className="size-3" />,
        },
      ],
      image: "/projects/braveheart-thumbnail.png",
      video: "",
    },
    {
      title: "CS Survival Guide & Kit",
      href: "https://survival-guide.jwall.engineering/",
      dates: "October 2026 - Present",
      active: true,
      description:
        "A field guide to computer science fundamentals: algorithms, data structures, system design, databases, networking, operating systems, and AI. Its companion library, the CS Survival Kit, is every data structure and algorithm from the guide hand-written in Python, published on PyPI with a stdlib-only benchmarking toolkit that checks real scaling against the complexity each docstring claims. The guide's reference section renders straight from the kit's source. An ongoing study of CS and DSA: clarity over cleverness.",
      technologies: ["Python", "Algorithms", "Data Structures", "System Design", "Benchmarking"],
      links: [
        {
          type: "Guide",
          href: "https://survival-guide.jwall.engineering/",
          icon: <Icons.globe className="size-3" />,
        },
        {
          type: "PyPI",
          href: "https://pypi.org/project/cs-survival-kit/",
          icon: <Package className="size-3" />,
        },
      ],
      image: "/projects/cs-survival-guide-thumbnail.png",
      video: "",
    },
    {
      title: "Prog Strength",
      href: "https://github.com/Prog-Strength",
      dates: "May 2026 - November 2026",
      active: false,
      description:
        "An AI-native fitness platform (web + iOS beta) where a conversational AI coach was the primary interface: log lifts, track macros, and get strength, nutrition, and running coaching by text, voice, or meal photo. An MCP server was the strict boundary between the LLM and the Go API, exposing 20+ typed tools regression-tested by a 77-case eval harness in CI. Built with an autonomous pipeline that dispatched Claude Code agents on ephemeral EC2 instances. Retired on purpose in November 2026 to cut hosting costs; the code and data are archived.",
      technologies: ["Go", "Next.js", "Expo", "FastAPI", "MCP", "AWS"],
      links: [
        {
          type: "GitHub",
          href: "https://github.com/Prog-Strength",
          icon: <Icons.github className="size-3" />,
        },
        {
          type: "Archive",
          href: "https://github.com/Prog-Strength/prog-strength-archive",
          icon: <Archive className="size-3" />,
        },
      ],
      image: "/projects/prog-strength-thumbnail.png",
      video: "",
    },
  ],
  // TODO: hackathons, if any. The section is disabled above until you add some.
  hackathons: [
    {
      title: "TODO: Hackathon",
      dates: "TODO: Month Day - Day, Year",
      location: "TODO: City, ST",
      description: "TODO: What you built.",
      image: "",
      win: "",
      links: [
        {
          title: "Source",
          icon: <Icons.github className="h-4 w-4" />,
          href: "https://github.com/jwallace145",
        },
      ],
    },
  ],
} as const;
